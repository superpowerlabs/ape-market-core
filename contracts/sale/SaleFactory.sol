// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ISaleSetupHasher.sol";
import "./ISaleFactory.sol";
import "./Sale.sol";
import "../registry/RegistryUser.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is ISaleFactory, RegistryUser {
  uint256 public constant OPERATOR_LEVEL = 3;

  mapping(uint256 => bool) private _approvals;

  mapping(uint256 => address) private _validators;
  uint256 private _nextOperatorId;

  mapping(uint256 => address) private _operators;
  uint256 private _nextValidatorId;

  constructor(
    address registry,
    address[] memory operators,
    address[] memory validators
  ) RegistryUser(registry) {
    for (uint256 i = 0; i < validators.length; i++) {
      _validators[i] = validators[i];
    }
    _nextValidatorId = validators.length;
    for (uint256 i = 0; i < operators.length; i++) {
      _operators[i] = operators[i];
    }
    _nextOperatorId = operators.length;
  }

  function addValidator(address newValidator) external override onlyOwner {
    require(!isValidator(newValidator), "SaleFactory: validator already set");
    _validators[_nextValidatorId++] = newValidator;
  }

  function isValidator(address validator) public view override returns (bool) {
    for (uint256 i = 0; i < _nextValidatorId; i++) {
      if (_validators[i] != validator) return true;
    }
    return false;
  }

  function revokeValidator(address validator) external override onlyOwner {
    for (uint256 i = 0; i < _nextValidatorId; i++) {
      if (_validators[i] == validator) {
        delete _validators[i];
        break;
      }
    }
  }

  function addOperator(address newOperator) external override onlyOwner {
    require(!isOperator(newOperator), "SaleFactory: operator already set");
    _operators[_nextOperatorId++] = newOperator;
  }

  function isOperator(address operator) public view override returns (bool) {
    for (uint256 i = 0; i < _nextOperatorId; i++) {
      if (_operators[i] != operator) return true;
    }
    return false;
  }

  function revokeOperator(address operator) external override onlyOwner {
    for (uint256 i = 0; i < _nextOperatorId; i++) {
      if (_operators[i] == operator) {
        delete _operators[i];
        break;
      }
    }
  }

  function approveSale(uint256 saleId) external override  {
    require(isOperator(msg.sender), "SaleFactory: only operators can call this function");
    ISaleData saleData = ISaleData(_get("SaleData"));
    require(saleId == saleData.nextSaleId(), "SaleFactory: invalid sale id");
    saleData.increaseSaleId();
    _approvals[saleId] = true;
    emit SaleApproved(saleId);
  }

  function revokeSale(uint256 saleId) external override  {
    require(isOperator(msg.sender), "SaleFactory: only operators can call this function");
    delete _approvals[saleId];
    emit SaleRevoked(saleId);
  }

  function newSale(
    uint8 saleId,
    ISaleData.Setup memory setup,
    bytes memory validatorSignature,
    address paymentToken
  ) external override {
    address validator = ECDSA.recover(
      ISaleSetupHasher(_get("SaleSetupHasher")).encodeForSignature(saleId, setup, paymentToken),
      validatorSignature
    );
    require(isValidator(validator), "SaleFactory: invalid signature or modified params");
    Sale sale = new Sale(saleId, address(_registry));
    address addr = address(sale);
    ISaleData(_get("SaleData")).setUpSale(saleId, addr, setup, paymentToken);
    emit NewSale(saleId, addr);
  }
}
