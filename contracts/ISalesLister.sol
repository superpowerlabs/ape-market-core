// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISalesLister {

  event FactorySet(address factory);

  event SAAdded(uint saId, address initialSale, uint256 remainingAmount, uint256 vestedPercentage);
  event SADeleted(uint saId);


  struct ListedSale {
    address sale;
    uint256 remainingAmount;
    uint256 vestedPercentage;
  }

  struct SA {
    ListedSale[] listedSales;
    uint256 creationBlock;
    uint256 acquisitionBlock;
  }


  function setFactory(address factory) external;

  function getFactory() external view returns (address);

  function getSA(uint saId) external view returns (SA memory);

  function addSA(uint saId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external returns (uint);

  function deleteSA(uint saId) external;

  function updateSA(uint saId) external returns (bool);

  function updateListedSale(uint saId, uint i, ListedSale memory sale) external;

  function getListedSale(uint saId, uint i) external view returns (ListedSale memory);

  function deleteListedSale(uint saId, uint i) external;

  function addNewSales(uint saId, ListedSale[] memory newSales) external;

  function deleteAllListedSales(uint saId) external;
}
