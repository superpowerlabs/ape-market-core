// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/LevelAccess.sol";
import "./ISAStorage.sol";

// for debugging only
import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeManager).
*/


contract SAStorage is ISAStorage, LevelAccess {
  // after deploying, we must grant SAToken and SAManager with MANAGER_LEVEL
  // so that they can handle the Bundle/SA storage

  using SafeMath for uint256;
  uint256 public constant MANAGER_LEVEL = 2;

  mapping(uint256 => Bundle) private _bundles;

  modifier bundleExists(uint256 bundleId) {
    require(_bundles[bundleId].creationTime != 0, "SAStorage: Bundle does not exist");
    _;
  }

  modifier SAExists(uint256 bundleId, uint256 i) {
    require(i < _bundles[bundleId].sas.length, "SAStorage: SA does not exist");
    _;
  }

  function getBundle(uint256 bundleId) public override virtual view
  returns (Bundle memory)
  {
    return _bundles[bundleId];
  }

  function newBundleWithSA(uint256 bundleId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    require(_bundles[bundleId].creationTime == 0, "SAStorage: Bundle already added");
    _newEmptyBundle(bundleId);
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    _addSAToBundle(bundleId, listedSale);
  }

  function newEmptyBundle(uint256 bundleId) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    _newEmptyBundle(bundleId);
  }

  function deleteBundle(uint256 bundleId) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    _deleteBundle(bundleId);
  }

  function updateBundleAcquisitionTime(uint256 bundleId) external override virtual
  onlyLevel(MANAGER_LEVEL)
  returns (bool)
  {
    if (_bundles[bundleId].sas.length > 0) {
      _bundles[bundleId].acquisitionTime = uint32(block.timestamp);
      return true;
    }
    return false;
  }

  function increaseAmountInSA(uint256 bundleId, uint256 i, uint256 diff) external override
  onlyLevel(MANAGER_LEVEL)
  {
    _bundles[bundleId].sas[i].remainingAmount = _bundles[bundleId].sas[i].remainingAmount.add(diff);
  }

  function addSAToBundle(uint256 bundleId, SA memory newSA) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    _addSAToBundle(bundleId, newSA);
  }

  // internal methods:

  function _newEmptyBundle(
    uint256 bundleId
  ) internal virtual
  {
    require(_bundles[bundleId].creationTime == 0, "SAStorage: Bundle already added");
    _bundles[bundleId].creationTime = uint32(block.timestamp);
    _bundles[bundleId].acquisitionTime = uint32(block.timestamp);
    emit BundleCreated(bundleId);
  }

  function _deleteBundle(uint256 bundleId) internal virtual
  bundleExists(bundleId)
  {
    delete _bundles[bundleId];
    emit BundleDeleted(bundleId);
  }

  function _addSAToBundle(uint256 bundleId, SA memory newSA) internal virtual
  bundleExists(bundleId)
  {
    _bundles[bundleId].sas.push(newSA);
    _bundles[bundleId].acquisitionTime = uint32(block.timestamp);
  }

}
