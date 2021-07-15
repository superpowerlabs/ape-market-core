// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Sale.sol";
//import "./ISalesLister.sol";

// for debugging only
import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeFactory).

*/


contract SalesLister is Ownable {

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
    uint256 creationTime; // when the SA is create = when it was first invested
    uint256 acquisitionTime; // == creation for first owner. == transfer time for later owners
  }


  address private _factory;
  mapping(uint256 => SA) internal _sas;

  // modifiers

  modifier onlyFactory() {
    require(_factory == msg.sender, "SalesLister: Caller is not an authorized factory");
    _;
  }

  modifier SAExists(uint saId) {
    require(_sas[saId].creationTime != 0, 'SalesLister: SA does not exist');
    _;
  }

  modifier ListedSaleExists(uint saId, uint i) {
    bool exists;
    for (uint j=0;j< _sas[saId].listedSales.length; j++) {
      if (j == i) {
        exists = true;
        break;
      }
    }
    require(exists, 'SalesLister: Listed sale does not exist');
    _;
  }

  constructor(address factory) {
    setFactory(factory);
  }

  function setFactory(address factory) public
  onlyOwner
  {
    _factory = factory;
    emit FactorySet(factory);
  }

  function getFactory() external view virtual returns (address)
  {
    return _factory;
  }

  function getSA(uint saId) public virtual view
  returns (SA memory)
  {
    return _sas[saId];
  }

  function addSA(
    uint saId,
    address saleAddress,
    uint256 remainingAmount,
    uint256 vestedPercentage
  ) external virtual
  onlyFactory
  returns (uint)
  {
    return _addSA(saId, saleAddress, remainingAmount, vestedPercentage);
  }

  function deleteSA(uint saId) external virtual
  onlyFactory
  {
    return _deleteSA(saId);
  }

  function updateSA(uint saId) public virtual
  onlyFactory
  returns (bool)
  {
    return _updateSA(saId);
  }

  function updateListedSale(uint saId, uint i, ListedSale memory sale) external
  onlyFactory
  {
    return _updateListedSale(saId, i, sale);
  }

  function getListedSale(uint saId, uint i) external view
  returns (ListedSale memory)
  {
    return _sas[saId].listedSales[i];
  }

  function deleteListedSale(uint saId, uint i) public virtual
  onlyFactory
  {
    _deleteListedSale(saId, i);
  }

  function addNewSales(uint saId, ListedSale[] memory newSales) external virtual
  onlyFactory
  {
    _addNewSales(saId, newSales);
  }

  function deleteAllListedSales(uint saId) external virtual
  onlyFactory
  {
    _deleteAllListedSales(saId);
  }


  // internal methods:

  function _addSA(
    uint saId,
    address saleAddress,
    uint256 remainingAmount,
    uint256 vestedPercentage
  ) internal virtual
  returns (uint)
  {
    require(_sas[saId].creationTime == 0, 'SalesLister: SA already added');
    ListedSale memory listedSale = ListedSale(saleAddress, remainingAmount, vestedPercentage);
    SA storage sa = _sas[saId];
    sa.listedSales.push(listedSale);
    _sas[saId].creationTime = block.timestamp;
    _sas[saId].acquisitionTime = block.timestamp;
    emit SAAdded(saId, saleAddress, remainingAmount, vestedPercentage);
    return saId;
  }

  function _deleteSA(uint saId) internal virtual
  SAExists(saId)
  {
    delete _sas[saId];
    emit SADeleted(saId);
  }

  function _updateSA(uint saId) internal virtual
  SAExists(saId)
  returns (bool)
  {
    if (_sas[saId].listedSales.length > 0) {
      _sas[saId].creationTime = block.timestamp;
      _sas[saId].acquisitionTime = block.timestamp;
      return true;
    }
    return false;
  }

  function _updateListedSale(uint saId, uint i, ListedSale memory sale) internal
  SAExists(saId) ListedSaleExists(saId, i)
  {
    //    console.log("In %s %s", i, _sas[saId].listedSales[i].sale);
    _sas[saId].listedSales[i] = sale;
  }

  function _deleteListedSale(uint saId, uint i) internal virtual
  SAExists(saId) ListedSaleExists(saId, i)
  {
    delete _sas[saId].listedSales[i];
  }

  function _addNewSales(uint saId, ListedSale[] memory newSales) internal virtual
  SAExists(saId)
  {
    for (uint256 i = 0; i < newSales.length; i++) {
      _sas[saId].listedSales.push(newSales[i]);
    }
  }

  function _deleteAllListedSales(uint saId) internal virtual
  SAExists(saId)
  {
    delete _sas[saId].listedSales;
  }


}
