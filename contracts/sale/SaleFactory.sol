// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/LevelAccess.sol";
import "./Sale.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is LevelAccess {

  event NewSale(address saleAddress);

  address private _lastSaleAddress;

  uint public constant FACTORY_ADMIN_LEVEL = 5;

  mapping(address => bool) private _sales;
  address[] private _allSales;

  address private _factoryAdmin;

  function isLegitSale(address sale) external view returns (bool) {
    return _sales[sale];
  }

  function lastSale() external view returns (address) {
    return _allSales[_allSales.length - 1];
  }

  function getSale(uint i) external view returns (address) {
    return _allSales[i];
  }

  function getAllSales() external view returns (address[] memory) {
    return _allSales;
  }

  function newSale(
    Sale.Setup memory setup,
    Sale.VestingStep[] memory schedule
  ) external
  onlyLevel(FACTORY_ADMIN_LEVEL)
  {
    Sale sale = new Sale(setup, schedule);
    sale.grantLevel(sale.SALE_OWNER_LEVEL(), setup.owner);
    address addr = address(sale);
    _allSales.push(addr);
    _sales[addr] = true;
    emit NewSale(addr);
  }

}
