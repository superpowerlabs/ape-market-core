// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Sale.sol";
import "./ISalesLister.sol";

// for debugging only
import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeFactory).

*/


contract SalesLister is ISalesLister, Ownable {

  address private _factory;
  mapping(uint256 => SA) internal _sas;

  // modifiers

  modifier onlyFactory() {
    require(_factory == msg.sender, "SalesLister: Caller is not an authorized factory");
    _;
  }

  modifier SAExists(uint saId) {
    require(_sas[saId].creationBlock != 0, "SalesLister: SA does not exist");
    _;
  }

  modifier ListedSaleExists(uint saId, uint i) {
    bool exists;
    for (uint j = 0; j < _sas[saId].listedSales.length; j++) {
      if (j == i) {
        exists = true;
        break;
      }
    }
    require(exists, "SalesLister: Listed sale does not exist");
    _;
  }

  constructor(address factory) {
    setFactory(factory);
  }

  function setFactory(address factory) public override
  onlyOwner
  {
    _factory = factory;
    emit FactorySet(factory);
  }

  function getFactory() external override view virtual returns (address)
  {
    return _factory;
  }

  function getSA(uint saId) external override virtual view
  returns (SA memory)
  {
    return _sas[saId];
  }

  function addSA(
    uint saId,
    address saleAddress,
    uint256 remainingAmount,
    uint256 vestedPercentage
  ) external override virtual
  onlyFactory
  returns (uint)
  {
    return _addSA(saId, saleAddress, remainingAmount, vestedPercentage);
  }

  function deleteSA(uint saId) external override virtual
  onlyFactory
  {
    return _deleteSA(saId);
  }

  function updateSA(uint saId) external override virtual
  onlyFactory
  returns (bool)
  {
    return _updateSA(saId);
  }

  function updateListedSale(uint saId, uint i, ListedSale memory sale) external override
  onlyFactory
  {
    return _updateListedSale(saId, i, sale);
  }

  function getListedSale(uint saId, uint i) external override view
  returns (ListedSale memory)
  {
    return _sas[saId].listedSales[i];
  }

  function deleteListedSale(uint saId, uint i) external override virtual
  onlyFactory
  {
    _deleteListedSale(saId, i);
  }

  function addNewSales(uint saId, ListedSale[] memory newSales) external override virtual
  onlyFactory
  {
    _addNewSales(saId, newSales);
  }

  function deleteAllListedSales(uint saId) external override virtual
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
    require(_sas[saId].creationBlock == 0, "SalesLister: SA already added");
    ListedSale memory listedSale = ListedSale(saleAddress, remainingAmount, vestedPercentage);
    SA storage sa = _sas[saId];
    sa.listedSales.push(listedSale);
    _sas[saId].creationBlock = block.number;
    _sas[saId].acquisitionBlock = block.number;
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
      _sas[saId].creationBlock = block.number;
      _sas[saId].acquisitionBlock = block.number;
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
