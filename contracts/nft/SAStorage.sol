// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISAStorage.sol";
import "../utils/LevelAccess.sol";

// for debugging only
//import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeManager).
*/


contract SAStorage is ISAStorage, LevelAccess {

  using SafeMath for uint256;

  uint256 public constant MANAGER_LEVEL = 1;

  mapping(uint256 => Bundle) private _bundles;

  modifier bundleExists(uint256 tokenId) {
    require(_bundles[tokenId].creationTime != 0, "SAStorage: Bundle does not exist");
    _;
  }

  modifier SAExists(uint256 tokenId, uint256 i) {
    require(i < _bundles[tokenId].sas.length, "SAStorage: SA does not exist");
    _;
  }

  function getBundle(uint256 tokenId) public override virtual view
  returns (Bundle memory)
  {
    return _bundles[tokenId];
  }

  function increaseAmountInSA(uint256 tokenId, uint256 i, uint256 diff) external override
  onlyLevel(MANAGER_LEVEL) {
    _increaseAmountInSA(tokenId, i, diff);
  }

  function addSAToBundle(uint256 tokenId, SA memory newSA) external override
  onlyLevel(MANAGER_LEVEL) {
    _addSAToBundle(tokenId, newSA);
  }

  // internals

  function _newBundleWithSA(uint256 tokenId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) internal virtual
  {
    require(_bundles[tokenId].creationTime == 0, "SAStorage: Bundle already added");
    _newEmptyBundle(tokenId);
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    _addSAToBundle(tokenId, listedSale);
  }

//  function _updateBundleAcquisitionTime(uint256 tokenId) internal virtual
//  returns (bool)
//  {
//    if (_bundles[tokenId].sas.length > 0) {
//      _bundles[tokenId].acquisitionTime = uint32(block.timestamp);
//      return true;
//    }
//    return false;
//  }

  function _increaseAmountInSA(uint256 tokenId, uint256 i, uint256 diff) internal
  {
    _bundles[tokenId].sas[i].remainingAmount = _bundles[tokenId].sas[i].remainingAmount.add(diff);
  }

  function _newEmptyBundle(
    uint256 tokenId
  ) internal virtual
  {
    require(_bundles[tokenId].creationTime == 0, "SAStorage: Bundle already added");
    _bundles[tokenId].creationTime = uint32(block.timestamp);
    _bundles[tokenId].acquisitionTime = uint32(block.timestamp);
    emit BundleCreated(tokenId);
  }

  function _deleteBundle(uint256 tokenId) internal virtual
  bundleExists(tokenId)
  {
    delete _bundles[tokenId];
    emit BundleDeleted(tokenId);
  }

  function _addSAToBundle(uint256 tokenId, SA memory newSA) internal virtual
  bundleExists(tokenId)
  {
    _bundles[tokenId].sas.push(newSA);
    _bundles[tokenId].acquisitionTime = uint32(block.timestamp);
  }

}
