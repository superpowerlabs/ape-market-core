// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ISaleSetupHasher.sol";
import "./ISaleFactory.sol";
import "./Sale.sol";
import "../registry/ApeRegistryAPI.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is ISaleFactory, ApeRegistryAPI {
  uint256 public constant OPERATOR_LEVEL = 3;

  mapping(uint256 => bool) private _approvals;

  mapping(uint256 => address) private _validators;
  mapping(uint256 => address) private _operators;
  uint256 private _nextValidatorId;

  constructor(
    address registry,
    address[] memory operators,
    address[] memory validators
  ) ApeRegistryAPI(registry) {
    for (uint256 i = 0; i < validators.length; i++) {
      _validators[i] = validators[i];
    }
    _nextValidatorId = validators.length;
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

  function approveSale(uint256 saleId) external override onlyLevel(OPERATOR_LEVEL) {
    ISaleData saleData = ISaleData(_get("SaleData"));
    require(saleId == _saleData.nextSaleId(), "SaleFactory: invalid sale id");
    _saleData.increaseSaleId();
    _approvals[saleId] = true;
    emit SaleApproved(saleId);
  }

  function revokeSale(uint256 saleId) external override onlyLevel(OPERATOR_LEVEL) {
    delete _approvals[saleId];
    emit SaleRevoked(saleId);
  }

  function newSale(
    uint8 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    bytes memory validatorSignature,
    address paymentToken
  ) external override {
    address validator = ECDSA.recover(ISaleSetupHasher(_get("SaleSetupHasher")).encodeForSignature(saleId, setup, schedule, paymentToken), validatorSignature);
    require(isValidator(validator), "SaleFactory: invalid signature or modified params");
    Sale sale = new Sale(saleId, address(_registry));
    address addr = address(sale);
    ISaleData(_get("SaleData")).setUpSale(saleId, addr, setup, schedule, paymentToken);
    emit NewSale(saleId, addr);
  }
}
