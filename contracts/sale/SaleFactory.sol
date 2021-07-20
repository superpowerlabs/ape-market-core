// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Sale.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is AccessControl {

  event NewSale(address saleAddress);

  address private _lastSaleAddress;

  bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

  mapping (address => bool) private _sales;
  address[] private _allSales;


  address private _factoryAdmin;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function grantRole(bytes32 role, address account) public virtual override {
    if (role == FACTORY_ADMIN_ROLE) {
      require(_factoryAdmin == account, "ApeFactory: Direct grant not allowed for factory manager");
    }
    super.grantRole(role, account);
  }

  function grantFactoryRole(address factoryAdmin) external
  onlyRole(DEFAULT_ADMIN_ROLE) {
    if (_factoryAdmin != address(0)) {
      revokeRole(FACTORY_ADMIN_ROLE, _factoryAdmin);
    }
    _factoryAdmin = factoryAdmin;
    grantRole(FACTORY_ADMIN_ROLE, factoryAdmin);
  }

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
  onlyRole(FACTORY_ADMIN_ROLE)
  {
    Sale sale = new Sale(setup, schedule);
    sale.grantRole(sale.SALE_OWNER_ROLE(), setup.owner);
    address addr = address(sale);
    _allSales.push(addr);
    _sales[addr] = true;
    emit NewSale(addr);
  }
}
