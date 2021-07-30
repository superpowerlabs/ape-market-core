// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAStorage {

  event BundleAdded(uint bundleId, address initialSale);
  event NewBundle(uint bundleId);
  event BundleDeleted(uint bundleId);

  struct SA {
    address sale;
    uint256 remainingAmount;
    uint128 vestedPercentage;
  }

  struct Bundle {
    SA[] sas;
    uint32 creationTimestamp;
    uint32 acquisitionTimestamp;
  }

  function getBundle(uint bundleId) external view returns (Bundle memory);

  function addBundleWithSA(uint bundleId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) external;

  function newBundle(uint bundleId) external;

  function deleteBundle(uint bundleId) external;

  function updateBundle(uint bundleId) external returns (bool);

  function updateSA(uint bundleId, uint i, uint128 vestedPercentage, uint vestedAmount) external;

  function changeSA(uint bundleId, uint i, uint diff, bool increase) external;

  function popSA(uint bundleId) external;

  function getSA(uint bundleId, uint i) external view returns (SA memory);

  function deleteSA(uint bundleId, uint i) external;

  function addNewSAs(uint bundleId, SA[] memory newSAs) external;

  function addNewSA(uint bundleId, SA memory newSA) external;

  function deleteAllSAs(uint bundleId) external;

  function cleanEmptySAs(uint256 tokenId, uint256 numEmptySAs) external returns (bool);
}
