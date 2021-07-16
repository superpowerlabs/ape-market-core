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
  mapping(uint256 => Bundle) internal _bundles;

  // modifiers

  modifier onlyFactory() {
    require(_factory == msg.sender, "SAOperator: Caller is not an authorized factory");
    _;
  }

  modifier BundleExists(uint boxId) {
    require(_bundles[boxId].creationBlock != 0, "SAOperator: Bundle does not exist");
    _;
  }

  modifier SAExists(uint boxId, uint i) {
    bool exists;
    for (uint j = 0; j < _bundles[boxId].sas.length; j++) {
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

  function getBundle(uint boxId) external override virtual view
  returns (Bundle memory)
  {
    return _bundles[boxId];
  }

  function addBundle(uint boxId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external override virtual
  onlyFactory
  returns (uint)
  {
    return _addBundle(boxId, saleAddress, remainingAmount, vestedPercentage);
  }

  function deleteBundle(uint boxId) external override virtual
  onlyFactory
  {
    return _deleteBundle(boxId);
  }

  function updateBundle(uint boxId) external override virtual
  onlyFactory
  returns (bool)
  {
    return _updateBundle(boxId);
  }

  function updateSA(uint boxId, uint i, SA memory sale) external override
  onlyFactory
  {
    return _updateSA(boxId, i, sale);
  }

  function getSA(uint boxId, uint i) external override view
  returns (SA memory)
  {
    return _bundles[boxId].sas[i];
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

  function _addBundle(
    uint boxId,
    address saleAddress,
    uint256 remainingAmount,
    uint256 vestedPercentage
  ) internal virtual
  returns (uint)
  {
    require(_bundles[boxId].creationBlock == 0, "SAOperator: Bundle already added");
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    Bundle storage box = _bundles[boxId];
    box.sas.push(listedSale);
    _bundles[boxId].creationBlock = block.number;
    _bundles[boxId].acquisitionBlock = block.number;
    emit BundleAdded(boxId, saleAddress, remainingAmount, vestedPercentage);
    return boxId;
  }

  function _deleteBundle(uint boxId) internal virtual
  BundleExists(boxId)
  {
    delete _bundles[boxId];
    emit BundleDeleted(boxId);
  }

  function _updateBundle(uint boxId) internal virtual
  BundleExists(boxId)
  returns (bool)
  {
    if (_bundles[boxId].sas.length > 0) {
      _bundles[boxId].creationBlock = block.number;
      _bundles[boxId].acquisitionBlock = block.number;
      return true;
    }
    return false;
  }

  function _updateSA(uint boxId, uint i, SA memory sale) internal
  BundleExists(boxId) SAExists(boxId, i)
  {
    //    console.log("In %s %s", i, _sas[boxId].sas[i].sale);
    _bundles[boxId].sas[i] = sale;
  }

  function _deleteSA(uint boxId, uint i) internal virtual
  BundleExists(boxId) SAExists(boxId, i)
  {
    delete _bundles[boxId].sas[i];
  }

  function _addNewSales(uint boxId, SA[] memory newSAs) internal virtual
  BundleExists(boxId)
  {
    for (uint256 i = 0; i < newSAs.length; i++) {
      _bundles[boxId].sas.push(newSAs[i]);
    }
    _bundles[boxId].acquisitionBlock = block.number;
    _bundles[boxId].creationBlock = block.number;
  }

  function _addNewSale(uint boxId, SA memory newSA) internal virtual
  BundleExists(boxId)
  {
      _bundles[boxId].sas.push(newSA);
      _bundles[boxId].acquisitionBlock = block.number;
      _bundles[boxId].creationBlock = block.number;
  }

  function _deleteAllSAs(uint boxId) internal virtual
  BundleExists(boxId)
  {
    delete _bundles[boxId].sas;
  }


}
