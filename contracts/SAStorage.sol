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

  function getBundle(uint bundleId) public override virtual view
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

  function cleanEmptySAs(uint256 bundleId, uint256 numEmptySAs) external virtual override
  BundleExists(bundleId) onlyRole(MANAGER_ROLE)
  returns(bool) {
    return _cleanEmptySAs(bundleId, numEmptySAs);
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

  // remove SAs that had no token left.  The containing Bundle will also be burned if all of
  // its SAs are empty and function returns false.
  function _cleanEmptySAs(uint256 bundleId, uint256 numEmptySAs) internal virtual
  returns(bool) {
    bool emptyBundle = false;
    Bundle storage bundle = _bundles[bundleId];
    if (bundle.sas.length == 0 || bundle.sas.length == numEmptySAs) {
      console.log("SANFT: Simple empty Bundle", bundleId, bundle.sas.length, numEmptySAs);
      emptyBundle = true;
    } else {
      console.log("SANFT: Regular process");
      if (numEmptySAs < bundle.sas.length/2) { // empty is less than half, then shift elements
        console.log("SANFT: Taking the shift route", bundle.sas.length, numEmptySAs);
        for (uint256 i = 0; i < bundle.sas.length; i++) {
          if (bundle.sas[i].remainingAmount == 0) {
            // find one SA from the end that's not 100% vested
            for(uint256 j = bundle.sas.length - 1; j > i; j--) {
              if(bundle.sas[j].remainingAmount > 0) {
                bundle.sas[i] = bundle.sas[j];
              }
              bundle.sas.pop();
            }
            // cannot find such SA
            if (bundle.sas[i].remainingAmount == 0) {
              assert(bundle.sas.length - 1 == i);
              bundle.sas.pop();
            }
          }
        }
      } else { // empty is more than half, then create a new array
        console.log("Taking the new array route", bundle.sas.length, numEmptySAs);
        SA[] memory newSAs = new SA[](bundle.sas.length - numEmptySAs);
        uint256 SAindex;
        for (uint256 i = 0; i < bundle.sas.length; i++) {
          if (bundle.sas[i].remainingAmount > 0) {
            newSAs[SAindex++] = bundle.sas[i];
          }
          delete bundle.sas[i];
        }
        delete bundle.sas;
        assert (bundle.sas.length == 0);
        for (uint256 i = 0; i < newSAs.length; i++) {
          bundle.sas.push(newSAs[i]);
        }
      }
    }
    if (emptyBundle || bundle.sas.length == 0) {
      _deleteBundle(bundleId);
      return false;
    }
    return true;
  }

}
