// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISAStorage.sol";
import "../sale/ISale.sol";
import "../utils/LevelAccess.sol";

import "hardhat/console.sol";

interface ISATokenMin {

  function nextTokenId() external view returns (uint);

  function mint(address to, address sale, uint256 amount, uint128 vestedPercentage) external;

  function burn(uint256 tokenId) external;

  function ownerOf(uint tokenId) external view returns (address);

  function vest(uint256 tokenId) external returns (bool);

}

interface IERC20Min {

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  function decimals() external view returns (uint8);

}

contract SAManager is LevelAccess {

  using SafeMath for uint256;

  ISATokenMin private _token;
  ISAStorage private _storage;
  ISale private _sale;

  address private _apeWallet;
  IERC20Min _feeToken;
  uint256 _feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer

  modifier feeRequired() {
    uint decimals = _feeToken.decimals();
    _feeToken.transferFrom(msg.sender, _apeWallet, _feeAmount.mul(10 ** decimals));
    _;
  }

  function _getPrimarySaleFeeToken(uint tokenId) internal view virtual
  returns (address) {
    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    ISale sale = ISale(bundle.sas[0].sale);
    return sale.getPaymentToken();
  }

  constructor(address tokenAddress, address storageAddress, address feeToken, uint feeAmount, address apeWallet_){
    _token = ISATokenMin(tokenAddress);
    _storage = ISAStorage(storageAddress);
    _feeToken = IERC20Min(feeToken);
    _feeAmount = feeAmount;
    _apeWallet = apeWallet_;
  }

  function updateToken(address newTokenAddress) external
  onlyLevel(OWNER_LEVEL) {
    _token = ISATokenMin(newTokenAddress);
  }

  function updateApeWallet(address apeWallet_) external
  onlyLevel(OWNER_LEVEL) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view
  returns (address) {
    return _apeWallet;
  }

  function merge(uint256[] memory tokenIds) external virtual feeRequired {
    uint nextId = _token.nextTokenId();
    uint counter;
    bool minted;
    console.log("gas left before merge", gasleft());
    ISAStorage.Bundle memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(_token.ownerOf(tokenIds[i]) == msg.sender, "SAManager: Only owner can merge tokens");
      for (uint w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) {
          revert("SAManager: Bundle can not merge to itself");
        }
      }
      bundle = _storage.getBundle(tokenIds[i]);
      bool notEmpty;
      for (uint256 j = 0; j < bundle.sas.length; j++) {
        if (bundle.sas[j].remainingAmount != 0) {
          notEmpty = true;
          if (!minted) {
            _token.mint(msg.sender, bundle.sas[j].sale, 0, 0);
            console.log("gas left after mint", gasleft());
            minted = true;
          }
          break;
        }
      }
      if (notEmpty) {
        counter++;
      }
    }
    require(counter > 1, "SAManager: Not enough SAs for merging");
    ISAStorage.Bundle memory newBundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _storage.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.sas.length; j++) {
        if (bundle.sas[j].remainingAmount == 0) {
          // we will skip empty SAs to save storage
          continue;
        }
        bool matched = false;
        newBundle = _storage.getBundle(nextId);
        for (uint256 k = 0; k < newBundle.sas.length; k++) {
          if (bundle.sas[j].sale == newBundle.sas[k].sale &&
            bundle.sas[j].vestedPercentage == newBundle.sas[k].vestedPercentage) {
            _storage.changeSA(nextId, k, bundle.sas[j].remainingAmount, true);
            console.log("gas left after increase to SA", gasleft());
            matched = true;
            break;
          }
        }
        if (!matched) {
          _storage.addNewSA(nextId, bundle.sas[j]);
          console.log("gas left after adding new SA", gasleft());
        }
      }
      _token.burn(tokenIds[i]);
    }
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual feeRequired {

    require(_token.ownerOf(tokenId) == msg.sender, "SAManager: Only owner can split a token");

    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    ISAStorage.SA[] memory sas = bundle.sas;
    console.log("gas left before split", gasleft());
    require(keptAmounts.length == bundle.sas.length, "SANFT: length of sa does not match split");
    bool minted;
    uint nextId = _token.nextTokenId();
    uint j;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(sas[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
      if (keptAmounts[i] == sas[j].remainingAmount) {
        // no changes
        j++;
        continue;
      }
      if (!minted) {
        _token.mint(msg.sender, sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        console.log("gas left after first mint", gasleft());
        _token.mint(msg.sender, sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
        console.log("gas left after second mint", gasleft());
        minted = true;
      } else {
        ISAStorage.SA memory newSA = ISAStorage.SA(sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        _storage.addNewSA(nextId, newSA);
        console.log("gas left after adding newSA", gasleft());
        if (keptAmounts[i] != 0) {
          newSA = ISAStorage.SA(sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
          _storage.addNewSA(nextId + 1, newSA);
          console.log("gas left after newSA to second token", gasleft());
          j++;
        }
      }
    }
    _token.burn(tokenId);
  }


}
