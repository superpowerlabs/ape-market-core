// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./Sale.sol";
import "./ISAStorage.sol";

// for debugging only
import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeManager).
*/


contract SAStorage is ISAStorage, AccessControl {

  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  mapping(uint256 => Bundle) private _bundles;

  modifier BundleExists(uint bundleId) {
    require(_bundles[bundleId].creationBlock != 0, "SAStorage: Bundle does not exist");
    _;
  }

  modifier SAExists(uint bundleId, uint i) {
    require(i < _bundles[bundleId].sas.length, "SAStorage: SA does not exist");
    _;
  }

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function getBundle(uint bundleId) external override virtual view
  returns (Bundle memory)
  {
    return _bundles[bundleId];
  }

  function addBundle(uint bundleId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external override virtual
  onlyRole(MANAGER_ROLE)
  returns (uint)
  {
    return _addBundle(bundleId, saleAddress, remainingAmount, vestedPercentage);
  }

  function deleteBundle(uint bundleId) external override virtual
  onlyRole(MANAGER_ROLE)
  {
    return _deleteBundle(bundleId);
  }

  function updateBundle(uint bundleId) external override virtual
  onlyRole(MANAGER_ROLE)
  returns (bool)
  {
    return _updateBundle(bundleId);
  }

  function updateSA(uint bundleId, uint i, SA memory sale) external override
  onlyRole(MANAGER_ROLE)
  {
    return _updateSA(bundleId, i, sale);
  }

  function getSA(uint bundleId, uint i) external override view
  returns (SA memory)
  {
    return _bundles[bundleId].sas[i];
  }

  function deleteSA(uint bundleId, uint i) external override virtual
  onlyRole(MANAGER_ROLE)
  {
    _deleteSA(bundleId, i);
  }

  function addNewSAs(uint bundleId, SA[] memory newSAs) external override virtual
  onlyRole(MANAGER_ROLE)
  {
    _addNewSAs(bundleId, newSAs);
  }

  function addNewSA(uint bundleId, SA memory newSA) external override virtual
  onlyRole(MANAGER_ROLE)
  {
    _addNewSA(bundleId, newSA);
  }

  function deleteAllSAs(uint bundleId) external override virtual
  onlyRole(MANAGER_ROLE)
  {
    _deleteAllSAs(bundleId);
  }


  // internal methods:

  function _addBundle(
    uint bundleId,
    address saleAddress,
    uint256 remainingAmount,
    uint256 vestedPercentage
  ) internal virtual
  returns (uint)
  {
    require(_bundles[bundleId].creationBlock == 0, "SAStorage: Bundle already added");
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    Bundle storage bundle = _bundles[bundleId];
    bundle.sas.push(listedSale);
    _bundles[bundleId].creationBlock = block.number;
    _bundles[bundleId].acquisitionBlock = block.number;
    emit BundleAdded(bundleId, saleAddress, remainingAmount, vestedPercentage);
    return bundleId;
  }

  function _deleteBundle(uint bundleId) internal virtual
  BundleExists(bundleId)
  {
    delete _bundles[bundleId];
    emit BundleDeleted(bundleId);
  }

  function _updateBundle(uint bundleId) internal virtual
  BundleExists(bundleId)
  returns (bool)
  {
    if (_bundles[bundleId].sas.length > 0) {
      _bundles[bundleId].acquisitionBlock = block.number;
      return true;
    }
    return false;
  }

  function _updateSA(uint bundleId, uint i, SA memory sale) internal
  BundleExists(bundleId) SAExists(bundleId, i)
  {
    _bundles[bundleId].sas[i] = sale;
  }

  function _deleteSA(uint bundleId, uint i) internal virtual
  BundleExists(bundleId) SAExists(bundleId, i)
  {
    delete _bundles[bundleId].sas[i];
  }

  function _addNewSAs(uint bundleId, SA[] memory newSAs) internal virtual
  BundleExists(bundleId)
  {
    for (uint256 i = 0; i < newSAs.length; i++) {
      _bundles[bundleId].sas.push(newSAs[i]);
    }
    _bundles[bundleId].acquisitionBlock = block.number;
  }

  function _addNewSA(uint bundleId, SA memory newSA) internal virtual
  BundleExists(bundleId)
  {
    _bundles[bundleId].sas.push(newSA);
    _bundles[bundleId].acquisitionBlock = block.number;
  }

  function _deleteAllSAs(uint bundleId) internal virtual
  BundleExists(bundleId)
  {
    delete _bundles[bundleId].sas;
  }


}
