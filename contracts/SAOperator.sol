// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Sale.sol";
import "./ISAOperator.sol";

// for debugging only
import "hardhat/console.sol";

/*
  This contract manages the sales inside a smart agreement.
  The actual smart agreement nft will extend this contract.
  Most functions will be managed internally and externally (by ApeFactory).

*/


contract SAOperator is ISAOperator, Ownable {

  address private _factory;
  mapping(uint256 => SABox) internal _SABoxes;

  // modifiers

  modifier onlyFactory() {
    require(_factory == msg.sender, "SAOperator: Caller is not an authorized factory");
    _;
  }

  modifier SABoxExists(uint boxId) {
    require(_SABoxes[boxId].creationBlock != 0, "SAOperator: SABox does not exist");
    _;
  }

  modifier SAExists(uint boxId, uint i) {
    bool exists;
    for (uint j = 0; j < _SABoxes[boxId].sas.length; j++) {
      if (j == i) {
        exists = true;
        break;
      }
    }
    require(exists, "SAOperator: SA does not exist");
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

  function getSABox(uint boxId) external override virtual view
  returns (SABox memory)
  {
    return _SABoxes[boxId];
  }

  function addSABox(uint boxId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external override virtual
  onlyFactory
  returns (uint)
  {
    return _addSABox(boxId, saleAddress, remainingAmount, vestedPercentage);
  }

  function deleteSABox(uint boxId) external override virtual
  onlyFactory
  {
    return _deleteSABox(boxId);
  }

  function updateSABox(uint boxId) external override virtual
  onlyFactory
  returns (bool)
  {
    return _updateSABox(boxId);
  }

  function updateSA(uint boxId, uint i, SA memory sale) external override
  onlyFactory
  {
    return _updateSA(boxId, i, sale);
  }

  function getSA(uint boxId, uint i) external override view
  returns (SA memory)
  {
    return _SABoxes[boxId].sas[i];
  }

  function deleteSA(uint boxId, uint i) external override virtual
  onlyFactory
  {
    _deleteSA(boxId, i);
  }

  function addNewSAs(uint boxId, SA[] memory newSales) external override virtual
  onlyFactory
  {
    _addNewSales(boxId, newSales);
  }

  function deleteAllSAs(uint boxId) external override virtual
  onlyFactory
  {
    _deleteAllSAs(boxId);
  }


  // internal methods:

  function _addSABox(
    uint boxId,
    address saleAddress,
    uint256 remainingAmount,
    uint256 vestedPercentage
  ) internal virtual
  returns (uint)
  {
    require(_SABoxes[boxId].creationBlock == 0, "SAOperator: SABox already added");
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    SABox storage box = _SABoxes[boxId];
    box.sas.push(listedSale);
    _SABoxes[boxId].creationBlock = block.number;
    _SABoxes[boxId].acquisitionBlock = block.number;
    emit SABoxAdded(boxId, saleAddress, remainingAmount, vestedPercentage);
    return boxId;
  }

  function _deleteSABox(uint boxId) internal virtual
  SABoxExists(boxId)
  {
    delete _SABoxes[boxId];
    emit SABoxDeleted(boxId);
  }

  function _updateSABox(uint boxId) internal virtual
  SABoxExists(boxId)
  returns (bool)
  {
    if (_SABoxes[boxId].sas.length > 0) {
      _SABoxes[boxId].creationBlock = block.number;
      _SABoxes[boxId].acquisitionBlock = block.number;
      return true;
    }
    return false;
  }

  function _updateSA(uint boxId, uint i, SA memory sale) internal
  SABoxExists(boxId) SAExists(boxId, i)
  {
    //    console.log("In %s %s", i, _sas[boxId].sas[i].sale);
    _SABoxes[boxId].sas[i] = sale;
  }

  function _deleteSA(uint boxId, uint i) internal virtual
  SABoxExists(boxId) SAExists(boxId, i)
  {
    delete _SABoxes[boxId].sas[i];
  }

  function _addNewSales(uint boxId, SA[] memory newSAs) internal virtual
  SABoxExists(boxId)
  {
    for (uint256 i = 0; i < newSAs.length; i++) {
      _SABoxes[boxId].sas.push(newSAs[i]);
    }
    _SABoxes[boxId].acquisitionBlock = block.number;
    _SABoxes[boxId].creationBlock = block.number;
  }

  function _addNewSale(uint boxId, SA memory newSA) internal virtual
  SABoxExists(boxId)
  {
      _SABoxes[boxId].sas.push(newSA);
      _SABoxes[boxId].acquisitionBlock = block.number;
      _SABoxes[boxId].creationBlock = block.number;
  }

  function _deleteAllSAs(uint boxId) internal virtual
  SABoxExists(boxId)
  {
    delete _SABoxes[boxId].sas;
  }


}
