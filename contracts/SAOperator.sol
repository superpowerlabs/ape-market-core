// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Sale.sol";
import "./ISAOperator.sol";

// for debugging only
import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeManager).
*/


contract SAOperator is ISAOperator, Ownable {

  address private _manager;
  mapping(uint256 => Bundle) private _bundles;

  modifier onlyManager() {
    require(_manager == msg.sender, "SAOperator: Caller is not authorized");
    _;
  }

  modifier BundleExists(uint bundleId) {
    require(_bundles[bundleId].creationBlock != 0, "SAOperator: Bundle does not exist");
    _;
  }

  modifier SAExists(uint bundleId, uint i) {
    require(i < _bundles[bundleId].sas.length, "SAOperator: SA does not exist");
    _;
  }

  function setManager(address manager) public override
  onlyOwner
  {
    _manager = manager;
    emit ManagerSet(manager);
  }

  function getManager() external override view virtual returns (address)
  {
    return _manager;
  }

  function getBundle(uint bundleId) external override virtual view
  returns (Bundle memory)
  {
    return _bundles[bundleId];
  }

  function addBundle(uint bundleId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external override virtual
  onlyManager
  returns (uint)
  {
    return _addBundle(bundleId, saleAddress, remainingAmount, vestedPercentage);
  }

  function deleteBundle(uint bundleId) external override virtual
  onlyManager
  {
    return _deleteBundle(bundleId);
  }

  function updateBundle(uint bundleId) external override virtual
  onlyManager
  returns (bool)
  {
    return _updateBundle(bundleId);
  }

  function updateSA(uint bundleId, uint i, SA memory sale) external override
  onlyManager
  {
    return _updateSA(bundleId, i, sale);
  }

  function getSA(uint bundleId, uint i) external override view
  returns (SA memory)
  {
    return _bundles[bundleId].sas[i];
  }

  function deleteSA(uint bundleId, uint i) external override virtual
  onlyManager
  {
    _deleteSA(bundleId, i);
  }

  function addNewSAs(uint bundleId, SA[] memory newSAs) external override virtual
  onlyManager
  {
    _addNewSAs(bundleId, newSAs);
  }

  function addNewSA(uint bundleId, SA memory newSA) external override virtual
  onlyManager
  {
    _addNewSA(bundleId, newSA);
  }

  function deleteAllSAs(uint bundleId) external override virtual
  onlyManager
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
    require(_bundles[bundleId].creationBlock == 0, "SAOperator: Bundle already added");
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