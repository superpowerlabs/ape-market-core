// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAOperator {

  event ManagerSet(address manager);

  event BundleAdded(uint bundleId, address initialSale, uint256 remainingAmount, uint256 vestedPercentage);
  event BundleDeleted(uint bundleId);

  struct SA {
    address sale;
    uint256 remainingAmount;
    uint256 vestedPercentage;
  }

  struct Bundle {
    SA[] sas;
    uint256 creationBlock;
    uint256 acquisitionBlock;
  }


  function setManager(address manager) external;

  function getManager() external view returns (address);

  function getBundle(uint bundleId) external view returns (Bundle memory);

  function addBundle(uint bundleId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external returns (uint);

  function deleteBundle(uint bundleId) external;

  function updateBundle(uint bundleId) external returns (bool);

  function updateSA(uint bundleId, uint i, SA memory sale) external;

  function getSA(uint bundleId, uint i) external view returns (SA memory);

  function deleteSA(uint bundleId, uint i) external;

  function addNewSAs(uint bundleId, SA[] memory newSAs) external;

  function addNewSA(uint bundleId, SA memory newSA) external;

  function deleteAllSAs(uint bundleId) external;
}
