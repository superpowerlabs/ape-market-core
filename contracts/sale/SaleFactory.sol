// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";

interface ISale {

  struct VestingStep {
    uint256 timestamp;
    uint256 percentage;
  }

  struct Setup {
    address satoken;
    uint256 minAmount;
    uint256 capAmount;
    uint256 remainingAmount;
    uint256 pricingToken;
    uint256 pricingPayment;
    address sellingToken;
    address paymentToken;
    address owner;
    uint256 tokenListTimestamp;
    uint256 tokenFeePercentage;
    uint256 paymentFeePercentage;
    bool isTokenTransferable;
  }

  function initialize(Setup memory setup_, VestingStep[] memory schedule) external;

  function grantRole(bytes32 role, address account) external;
}

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is AccessControl {

  event NewSale(address saleAddress, bytes32 salt);

  address private _lastSaleAddress;

  bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");

  mapping(address => bool) private _sales;
  address[] private _allSales;
  address private _sampleSale;

  address private _factoryAdmin;

  constructor(address sampleSale) {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _sampleSale = sampleSale;
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

  function getDeployedBytecode(address _addr) public view returns (bytes memory o_code) {
    assembly {
      let size := extcodesize(_addr)
      o_code := mload(0x40)
      mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
      mstore(o_code, size)
      extcodecopy(_addr, add(o_code, 0x20), 0, size)
    }
  }

  function newSale(
    ISale.Setup memory setup,
    ISale.VestingStep[] memory schedule
  ) external
  onlyRole(FACTORY_ADMIN_ROLE)
  {
    bytes memory bytecode = getDeployedBytecode(_sampleSale);
//    console.log("Size %s", deployedBytecode.length);
//    bytes memory bytecode = abi.encodePacked(deployedBytecode, abi.encode(setup, schedule));
    console.log("Size %s", bytecode.length);
    bytes32 salt = keccak256(abi.encodePacked(msg.sender, block.timestamp));
    address addr;
    assembly {
      addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
//      addr := create2(0, add(code, 0x20), mload(code), salt)
      if iszero(extcodesize(addr)) {
        revert(0, 0)
      }
    }
    ISale sale = ISale(addr);
    sale.initialize(setup, schedule);
    sale.grantRole(keccak256("SALE_OWNER_ROLE"), setup.owner);
    //    address addr = address(sale);
    _allSales.push(addr);
    _sales[addr] = true;
    emit NewSale(addr, salt);
  }

}
