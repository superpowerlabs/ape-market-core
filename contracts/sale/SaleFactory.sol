// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ISaleSetupHasher.sol";
import "./ISaleFactory.sol";
import "./ISaleDB.sol";
import "./Sale.sol";
import "../registry/RegistryUser.sol";

contract SaleFactory is ISaleFactory, RegistryUser {

  mapping(uint256 => bool) private _approvals;
  mapping(address => uint) private _operators;

  modifier onlyOperator(uint roles) {
    require(isOperator(_msgSender(), roles), "SaleFactory: only operators can call this function");
    _;
  }

  constructor(
    address registry,
    address[] memory operators,
    uint[] memory roles
  ) RegistryUser(registry) {
    for (uint256 i = 0; i < operators.length; i++) {
      _operators[operators[i]] = roles[i];
    }
  }

  ISaleData private _saleData;
  ISaleSetupHasher private _saleSetupHasher;
  ISaleDB private _saleDB;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get("SaleData");
    if (addr != address(_saleData)) {
      _saleData = ISaleData(addr);
    }
    addr = _get("SaleSetupHasher");
    if (addr != address(_saleSetupHasher)) {
      _saleSetupHasher = ISaleSetupHasher(addr);
    }
    addr = _get("SaleDB");
    if (addr != address(_saleDB)) {
      _saleDB = ISaleDB(addr);
    }
  }

  function addOperator(address newOperator, uint roles) external override onlyOwner {
    _operators[newOperator] = roles;
  }

  function isOperator(address operator, uint roles) public view override returns (bool) {
    return _operators[operator] & roles != 0;
  }

  function revokeOperator(address operator) external override onlyOwner {
    delete _operators[operator];
  }

  function approveSale(uint256 saleId) external override onlyOperator(1) {
    require(saleId == _saleDB.nextSaleId(), "SaleFactory: invalid sale id");
    _saleData.increaseSaleId();
    _approvals[saleId] = true;
    emit SaleApproved(saleId);
  }

  function revokeSale(uint256 saleId) external override onlyOperator(1) {
    delete _approvals[saleId];
    emit SaleRevoked(saleId);
  }

  function newSale(
    uint8 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken,
    bytes memory validatorSignature
  ) external override {
    address validator = ECDSA.recover(
      _saleSetupHasher.packAndHashSaleConfiguration(saleId, setup, extraVestingSteps, paymentToken),
      validatorSignature
    );
    require(isOperator(validator, 10), "SaleFactory: invalid signature or modified params");
    Sale sale = new Sale(saleId, address(_registry));
    address addr = address(sale);
    _saleData.setUpSale(saleId, addr, setup, extraVestingSteps, paymentToken);
    emit NewSale(saleId, addr);
  }
}
