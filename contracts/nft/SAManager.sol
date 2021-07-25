// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISAStorage.sol";
import "../sale/ISale.sol";
import "../utils/LevelAccess.sol";

import "hardhat/console.sol";

interface ISATokenMin {

  function mintWithExistingBundle(address to) external;

  function nextTokenId() external view returns (uint);

  function burn(uint256 tokenId) external;

  function ownerOf(uint tokenId) external view returns (address);

  function vest(uint256 tokenId) external returns (bool);

}

contract SAManager is LevelAccess {

  using SafeMath for uint256;

  ISATokenMin private _token;
  ISAStorage private _storage;
  ISale private _sale;

  address private _apeWallet;
  ERC20Min _feeToken;
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
    _feeToken = ERC20Min(feeToken);
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
    require(tokenIds.length >= 2, "SAManager: Not enough SAs for merging");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(_token.ownerOf(tokenIds[i]) == msg.sender, "SAManager: Only owner can merge tokens");
      for (uint w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) {
          revert("SAManager: Bundle can not merge to itself");
        }
      }
    }
    uint nextTokenId = _token.nextTokenId();
    _storage.newBundle(nextTokenId);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      ISAStorage.Bundle memory bundle = _storage.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.sas.length; j++) {
        if (bundle.sas[j].remainingAmount == 0) {
          // sa is empty
          continue;
        }
        bool matched = false;
        ISAStorage.Bundle memory newBundle = _storage.getBundle(nextTokenId);
        for (uint256 k = 0; k < newBundle.sas.length; k++) {
          if (bundle.sas[j].sale == newBundle.sas[k].sale &&
            bundle.sas[j].vestedPercentage == newBundle.sas[k].vestedPercentage) {
            _storage.changeSA(nextTokenId, k, bundle.sas[j].remainingAmount, true);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _storage.addNewSA(nextTokenId, bundle.sas[j]);
        }
      }
      _token.burn(tokenIds[i]);
    }
    _token.mintWithExistingBundle(msg.sender);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual feeRequired {

    require(_token.ownerOf(tokenId) == msg.sender, "SAManager: Only owner can split a token");

    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    ISAStorage.SA[] memory sas = bundle.sas;

    require(keptAmounts.length == bundle.sas.length, "SANFT: length of sa does not match split");
    bool created;
    uint nextTokenId = _token.nextTokenId();
    uint j;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(sas[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
      if (keptAmounts[i] == sas[j].remainingAmount) {
        // no changes
        j++;
        continue;
      }
      if (!created) {
        _storage.addBundleWithSA(nextTokenId, sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        _token.mintWithExistingBundle(msg.sender);
        _storage.addBundleWithSA(nextTokenId + 1, sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
        _token.mintWithExistingBundle(msg.sender);
        created = true;
      } else {
        ISAStorage.SA memory newSA = ISAStorage.SA(sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        _storage.addNewSA(nextTokenId, newSA);
        if (keptAmounts[i] != 0) {
          newSA = ISAStorage.SA(sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
          _storage.addNewSA(nextTokenId + 1, newSA);
          j++;
        }
      }
    }
    _token.burn(tokenId);
  }


}
