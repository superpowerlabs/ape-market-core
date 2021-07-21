// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./ISAStorage.sol";
import "../sale/ISale.sol";


interface ISATokenOptimized {

  function pause(uint tokenId) external;

  function unpause(uint tokenId) external;

  function pauseBatch(uint[] memory tokenIds) external;

  function unpauseBatch(uint[] memory tokenIds) external;

  function isPaused(uint tokenId) external view returns (bool);

  function updateFactory(address factoryAddress) external;

  function updateStorage(address storageAddress) external;

  function factory() external view returns (address);

  function mint(address to, uint256 amount) external;

  function burn(uint256 tokenId) external;

  function ownerOf(uint tokenId) external view returns (address);

  function vest(uint256 tokenId) external returns (bool);

}

contract SAManager is AccessControl {

  using SafeMath for uint256;

  ISATokenOptimized private _token;
  ISAStorage private _storage;
  ISale private _sale;
  address private _apeWallet;

  // TODO: must manage this dynamically
  uint private _feeAmount = 1;

  modifier feeRequired(uint tokenId) {
    // TODO: should we transfer instead from the user's SAs to the Ape's SAs?
    // Is the feetoken the same for any sale? It may not be, right?
    // Does the user pay with the feeToken used in the primary sale, i.e., sas[0]?
    address paymentToken = _getPrimarySaleFeeToken(tokenId);
    IERC20(paymentToken).transferFrom(msg.sender, _apeWallet, _feeAmount);
    _;
  }

  function _getPrimarySaleFeeToken(uint tokenId) internal view virtual
  returns (address) {
    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    ISale sale = ISale(bundle.sas[0].sale);
    return sale.getPaymentToken();
  }

  constructor(address tokenAddress, address storageAddress){
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _token = ISATokenOptimized(tokenAddress);
    _storage = ISAStorage(storageAddress);
  }

  function updateToken(address newTokenAddress) external
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _token = ISATokenOptimized(newTokenAddress);
  }

  function setApeWallet(address apeWallet_) external
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view
  returns (address) {
    return _apeWallet;
  }

  function merge(uint256[] memory tokenIds, bool vestTokensBeforeMerging) external virtual
  // lets assume for now that they pay with the feetoken used in the primary SA
  feeRequired(tokenIds[0]) {
    require(tokenIds.length >= 2, "SAManager: Not enough SAs for merging");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(_token.ownerOf(tokenIds[i]) == msg.sender, "SAManager: Only owner can merge bundle");
    }
    if (vestTokensBeforeMerging && !_token.vest(tokenIds[0])) {
      return;
    }

    ISAStorage.Bundle memory bundle0 = _storage.getBundle(tokenIds[0]);
    // keep this in a variable since sa0.sas will change
    uint256 bundle0Len = bundle0.sas.length;
    for (uint256 i = 1; i < tokenIds.length; i++) {
      require(tokenIds[0] != tokenIds[i], "SAManager: Bundle can not merge to itself");
      if (vestTokensBeforeMerging && !_token.vest(tokenIds[i])) {
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
            _storage.popSA(tokenIds[j]);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _storage.addNewSA(tokenIds[0], bundle1.sas[j]);
        }
      }
      _token.burn(tokenIds[i]);
    }
  }

//  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual onlyNFTOwner(tokenId) feeRequired {
//    if (!vest(tokenId)) {
//      return;
//    }
//    ISAStorage.Bundle storage bundle = _bundles[tokenId];
//    ISAStorage.SA[] storage sas = bundle.sas;
//
//    require(keptAmounts.length == bundle.sas.length, "SANFT: length of sa does not match split");
//    uint256 numEmptySAs;
//    for (uint256 i = 0; i < keptAmounts.length; i++) {
//      require(sas[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
//      if (keptAmounts[i] == 0) {
//        numEmptySAs++;
//      }
//      uint256 newSAAmount = sas[i].remainingAmount - keptAmounts[i];
//      if(newSAAmount > 0) {
//        ISAStorage.Bundle storage newBundle = _bundles[_nextTokenId];
//        ISAStorage.SA memory newSA = SA(sas[i].sale, sas[i].remainingAmount - keptAmounts[i], 0);
//        newBundle.sas.push(newSA);
//      }
//      sas[i].remainingAmount = keptAmounts[i];
//    }
//    if (_bundles[_nextTokenId].sas.length > 0) {
//      _bundles[_nextTokenId].creationTime = block.timestamp;
//      _bundles[_nextTokenId].acquisitionTime = block.timestamp;
//      _mint(msg.sender, _nextTokenId++);
//    }
////    cleanEmptySAs(bundle, tokenId, numEmptySAs);
//  }

}
