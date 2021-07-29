// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/LevelAccess.sol";
import "./Sale.sol";
import "./ISaleData.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is LevelAccess {

  event NewSale(address saleAddress);


  mapping(address => bool) private _sales;
  address[] private _allSales;

  uint public constant FACTORY_ADMIN_LEVEL = 5;
  address private _factoryAdmin;

  function isLegitSale(address sale) external view returns (bool) {
    return _sales[sale];
  }

  function lastSale() external view returns (address) {
    if (_allSales.length == 0) {
      return address(0);
    } else {
      return _allSales[_allSales.length - 1];
    }
  }

  function getSale(uint i) external view returns (address) {
    return _allSales[i];
  }

  function getAllSales() external view returns (address[] memory) {
    return _allSales;
  }

  function newSale(
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    address apeWallet,
    address saleDataAddress
  ) external
  onlyLevel(FACTORY_ADMIN_LEVEL)
  {
    Sale sale = new Sale(apeWallet, saleDataAddress);
    address addr = address(sale);
    ISaleData saleData = ISaleData(saleDataAddress);
    saleData.grantManagerLevel(addr);
    sale.initialize(setup, schedule);
    _allSales.push(addr);
    _sales[addr] = true;
    emit NewSale(addr);
  }

}
