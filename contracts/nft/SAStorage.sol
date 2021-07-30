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
  uint public constant MANAGER_LEVEL = 2;

  mapping(uint256 => Bundle) private _bundles;

  modifier bundleExists(uint bundleId) {
    require(_bundles[bundleId].creationTimestamp != 0, "SAStorage: Bundle does not exist");
    _;
  }

  modifier SAExists(uint bundleId, uint i) {
    require(i < _bundles[bundleId].sas.length, "SAStorage: SA does not exist");
    _;
  }

  function getBundle(uint bundleId) public override virtual view
  returns (Bundle memory)
  {
    return _bundles[bundleId];
  }

  function newBundleWithSA(uint bundleId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    require(_bundles[bundleId].creationTimestamp == 0, "SAStorage: Bundle already added");
    _newEmptyBundle(bundleId);
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    _addSAToBundle(bundleId, listedSale);
    emit BundleAdded(bundleId, saleAddress);
  }

  function newEmptyBundle(uint bundleId) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    _newEmptyBundle(bundleId);
  }

  function deleteBundle(uint bundleId) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    _deleteBundle(bundleId);
  }

  function updateBundle(uint bundleId) external override virtual
  onlyLevel(MANAGER_LEVEL)
  returns (bool)
  {
    if (_bundles[bundleId].sas.length > 0) {
      _bundles[bundleId].acquisitionTimestamp = uint32(block.timestamp);
      return true;
    }
    return false;
  }

  function increaseAmountInSA(uint bundleId, uint i, uint diff) external override
  onlyLevel(MANAGER_LEVEL)
  {
    _bundles[bundleId].sas[i].remainingAmount = _bundles[bundleId].sas[i].remainingAmount.add(diff);
  }

  function decreaseAmountInSA(uint bundleId, uint i, uint diff) external override
  onlyLevel(MANAGER_LEVEL)
  {
    _bundles[bundleId].sas[i].remainingAmount = _bundles[bundleId].sas[i].remainingAmount.sub(diff);
  }

  function addSAToBundle(uint bundleId, SA memory newSA) external override virtual
  onlyLevel(MANAGER_LEVEL)
  {
    _addSAToBundle(bundleId, newSA);
  }

  function cleanEmptySAs(uint256 bundleId, uint256 numEmptySAs) external virtual override
  bundleExists(bundleId) onlyLevel(MANAGER_LEVEL)
  returns (bool) {
    return _cleanEmptySAs(bundleId, numEmptySAs);
  }


  // internal methods:

  function _newEmptyBundle(
    uint bundleId
  ) internal virtual
  {
    require(_bundles[bundleId].creationTimestamp == 0, "SAStorage: Bundle already added");
    _bundles[bundleId].creationTimestamp = uint32(block.timestamp);
    _bundles[bundleId].acquisitionTimestamp = uint32(block.timestamp);
    emit NewBundle(bundleId);
  }

  function _deleteBundle(uint bundleId) internal virtual
  bundleExists(bundleId)
  {
    delete _bundles[bundleId];
    emit BundleDeleted(bundleId);
  }

  function _addSAToBundle(uint bundleId, SA memory newSA) internal virtual
  bundleExists(bundleId)
  {
    _bundles[bundleId].sas.push(newSA);
    _bundles[bundleId].acquisitionTimestamp = uint32(block.timestamp);
  }

  // _cleanEmptySAs looks not very useful.
  // We will verify and possibly optimize it later.
  function _cleanEmptySAs(uint256 bundleId, uint256 numEmptySAs) internal virtual
  returns (bool) {
    bool emptyBundle = false;
    Bundle storage bundle = _bundles[bundleId];
    if (bundle.sas.length == 0 || bundle.sas.length == numEmptySAs) {
      console.log("SANFT: Simple empty Bundle", bundleId, bundle.sas.length, numEmptySAs);
      emptyBundle = true;
    } else {
      console.log("SANFT: Regular process");
      if (numEmptySAs < bundle.sas.length / 2) {// empty is less than half, then shift elements
        console.log("SANFT: Taking the shift route", bundle.sas.length, numEmptySAs);
        for (uint256 i = 0; i < bundle.sas.length; i++) {
          if (bundle.sas[i].remainingAmount == 0) {
            // find one SA from the end that's not 100% vested
            for (uint256 j = bundle.sas.length - 1; j > i; j--) {
              if (bundle.sas[j].remainingAmount > 0) {
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
      } else {// empty is more than half, then create a new array
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
        assert(bundle.sas.length == 0);
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
