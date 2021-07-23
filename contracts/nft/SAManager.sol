// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
  IERC20 _feeToken;
  uint256 _feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer

  modifier feeRequired() {
    console.log(1);
    _feeToken.transferFrom(msg.sender, _apeWallet, _feeAmount);
    console.log(2);
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
    _feeToken = IERC20(feeToken);
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

  function merge(uint256[] memory tokenIds, bool vestTokensBefore) external virtual feeRequired {
    require(tokenIds.length >= 2, "SAManager: Not enough SAs for merging");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(_token.ownerOf(tokenIds[i]) == msg.sender, "SAManager: Only owner can merge tokens");
    }
    if (vestTokensBefore && !_token.vest(tokenIds[0])) {
      return;
    }

    ISAStorage.Bundle memory bundle0 = _storage.getBundle(tokenIds[0]);
    // keep this in a variable since sa0.sas will change
    uint256 bundle0Len = bundle0.sas.length;
    for (uint256 i = 1; i < tokenIds.length; i++) {
      require(tokenIds[0] != tokenIds[i], "SAManager: Bundle can not merge to itself");
      if (vestTokensBefore && !_token.vest(tokenIds[i])) {
        continue;
      }
      ISAStorage.Bundle memory bundle1 = _storage.getBundle(tokenIds[i]);
      // go through each sa in bundle1, and compare with every sa
      // in bundle0, if same sale then combine and update the matching sa, otherwise, push
      // into bundle0.
      for (uint256 j = 0; j < bundle1.sas.length; j++) {
        bool matched = false;
        for (uint256 k = 0; k < bundle0Len; k++) {
          if (bundle1.sas[j].sale == bundle0.sas[k].sale) {
            _storage.changeSA(tokenIds[j], k, bundle1.sas[j].remainingAmount, true);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _storage.addNewSA(tokenIds[0], bundle1.sas[j]);
        }
        _storage.deleteSA(tokenIds[i], j);
      }
      _token.burn(tokenIds[i]);
    }
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts, bool vestTokensBefore) public virtual feeRequired {

    require(_token.ownerOf(tokenId) == msg.sender, "SAManager: Only owner can split a token");

    if (vestTokensBefore && !_token.vest(tokenId)) {
      return;
    }
    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    ISAStorage.SA[] memory sas = bundle.sas;

    require(keptAmounts.length == bundle.sas.length, "SANFT: length of sa does not match split");
    bool created;
    uint nextTokenId = _token.nextTokenId();
    uint j = 0;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(sas[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
      if (keptAmounts[i] == sas[j].remainingAmount) {
        // no changes
        j++;
        continue;
      }
//      console.log("Kept %s", keptAmounts[i]);
      _storage.changeSA(tokenId, j, sas[i].remainingAmount.sub(keptAmounts[i]), false);
      if (!created) {
        console.log("Changed %s", sas[i].remainingAmount.sub(keptAmounts[i]));
        _storage.addBundle(nextTokenId, sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), 0);
        _token.mintWithExistingBundle(msg.sender);
        created = true;
      } else {
        ISAStorage.SA memory newSA = ISAStorage.SA(sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), 0);
        _storage.addNewSA(nextTokenId, newSA);
      }
      if (keptAmounts[i] == 0) {
        _storage.deleteSA(tokenId, j);
      } else {
        j++;
      }
      sas[i].remainingAmount = keptAmounts[i];
    }
  }


}
