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

  function newBundleWithSA(uint bundleId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) external;

  function newEmptyBundle(uint bundleId) external;

  function deleteBundle(uint bundleId) external;

  function updateBundle(uint bundleId) external returns (bool);

  function increaseAmountInSA(uint bundleId, uint i, uint diff) external;

  function decreaseAmountInSA(uint bundleId, uint i, uint diff) external;

  function addSAToBundle(uint bundleId, SA memory newSA) external;

  function cleanEmptySAs(uint256 tokenId, uint256 numEmptySAs) external returns (bool);
}
