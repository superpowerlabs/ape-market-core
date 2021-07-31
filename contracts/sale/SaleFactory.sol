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
  mapping(uint256 => address) private _salesById;
  uint256 private _lastSaleId;

  uint256 public constant FACTORY_ADMIN_LEVEL = 3;
  address private _factoryAdmin;

  function isLegitSale(address sale) external view returns (bool) {
    return _sales[sale];
  }

  function lastSale() external view returns (address) {
    return _salesById[_lastSaleId];
  }

  function getSaleAddressById(uint256 i) external view returns (address) {
    return _salesById[i];
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
    _lastSaleId = sale.saleId();
    _salesById[_lastSaleId] = addr;
    _sales[addr] = true;
    emit NewSale(addr);
  }

}
