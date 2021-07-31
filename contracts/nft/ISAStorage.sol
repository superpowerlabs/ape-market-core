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

  function increaseAmountInSA(uint256 bundleId, uint256 saIndex, uint256 diff) external;

  function addSAToBundle(uint256 bundleId, SA memory newSA) external;

}
