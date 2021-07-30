// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAStorage {

  event BundleCreated(uint256 bundleId);
  event BundleDeleted(uint256 bundleId);

  struct SA {
    address sale;
    uint256 remainingAmount;
    uint128 vestedPercentage;
  }

  struct Bundle {
    SA[] sas;
    uint32 creationTime;
    uint32 acquisitionTime;
  }

  function getBundle(uint256 bundleId) external view returns (Bundle memory);

  function newBundleWithSA(uint256 bundleId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) external;

  function newEmptyBundle(uint256 bundleId) external;

  function deleteBundle(uint256 bundleId) external;

  function updateBundleAcquisitionTime(uint256 bundleId) external returns (bool);

  function increaseAmountInSA(uint256 bundleId, uint256 i, uint256 diff) external;

  function addSAToBundle(uint256 bundleId, SA memory newSA) external;

}
