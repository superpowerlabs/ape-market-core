// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAOperator {

  event FactorySet(address factory);

  event BundleAdded(uint boxId, address initialSale, uint256 remainingAmount, uint256 vestedPercentage);
  event BundleDeleted(uint boxId);

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


  function setFactory(address factory) external;

  function getFactory() external view returns (address);

  function getBundle(uint boxId) external view returns (Bundle memory);

  function addBundle(uint boxId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external returns (uint);

  function deleteBundle(uint boxId) external;

  function updateBundle(uint boxId) external returns (bool);

  function updateSA(uint boxId, uint i, SA memory sale) external;

  function getSA(uint boxId, uint i) external view returns (SA memory);

  function deleteSA(uint boxId, uint i) external;

  function addNewSAs(uint boxId, SA[] memory newSAs) external;

  function deleteAllSAs(uint boxId) external;
}
