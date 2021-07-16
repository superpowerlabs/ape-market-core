// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAOperator {

  event FactorySet(address factory);

  event SABoxAdded(uint boxId, address initialSale, uint256 remainingAmount, uint256 vestedPercentage);
  event SABoxDeleted(uint boxId);

  struct SA {
    address sale;
    uint256 remainingAmount;
    uint256 vestedPercentage;
  }

  struct SABox {
    SA[] sas;
    uint256 creationBlock;
    uint256 acquisitionBlock;
  }


  function setFactory(address factory) external;

  function getFactory() external view returns (address);

  function getSABox(uint boxId) external view returns (SABox memory);

  function addSABox(uint boxId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external returns (uint);

  function deleteSABox(uint boxId) external;

  function updateSABox(uint boxId) external returns (bool);

  function updateSA(uint boxId, uint i, SA memory sale) external;

  function getSA(uint boxId, uint i) external view returns (SA memory);

  function deleteSA(uint boxId, uint i) external;

  function addNewSAs(uint boxId, SA[] memory newSAs) external;

  function deleteAllSAs(uint boxId) external;
}
