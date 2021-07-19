// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Sale2.sol";
import "./ISAStorage.sol";

// for debugging only
//import "hardhat/console.sol";

contract ApeFactory is AccessControl {

  event NewSale(address saleAddress);

  bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

  mapping (address => bool) private _sales;

  ISAStorage private _storage;

  address private _factoryAdmin;

  constructor(address storageAddress) {
    _storage = ISAStorage(storageAddress);
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

  function newSale(
    Sale2.Setup memory setup,
    Sale2.VestingStep[] memory schedule
  ) external
  onlyRole(FACTORY_ADMIN_ROLE)
  returns(address) {
    require(address(_storage) != address(0), "ApeFactory: SAStorage not set yet");
    Sale2 sale = new Sale2(setup, schedule);
    sale.grantRole(sale.SALE_OWNER_ROLE(), setup.owner);
    _sales[address(sale)] = true;
    emit NewSale(address(sale));
    return address(sale);
  }
}
