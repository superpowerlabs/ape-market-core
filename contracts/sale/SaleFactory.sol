// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../utils/LevelAccess.sol";
import "./ISaleSetupHasher.sol";
import "./ISaleFactory.sol";
import "./Sale.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is ISaleFactory, LevelAccess {
  uint256 public constant OPERATOR_LEVEL = 3;

  mapping(uint256 => bool) private _approvals;

  ISaleData private _saleData;
  ISaleSetupHasher private _hasher;

  mapping(uint256 => address) private _validators;
  uint256 private _nextValidatorId;

  constructor(
    address saleData,
    address hasher,
    address[] memory validators
  ) {
    _saleData = ISaleData(saleData);
    _hasher = ISaleSetupHasher(hasher);
    for (uint256 i = 0; i < validators.length; i++) {
      _validators[i] = validators[i];
    }
    _nextValidatorId = validators.length;
  }

  function addValidator(address newValidator) external override onlyLevel(OWNER_LEVEL) {
    require(!isValidator(newValidator), "SaleFactory: validator already set");
    _validators[_nextValidatorId++] = newValidator;
  }

  function isValidator(address validator) public view override returns (bool) {
    for (uint256 i = 0; i < _nextValidatorId; i++) {
      if (_validators[i] != validator) return true;
    }
    return false;
  }

  function revokeValidator(address validator) external override onlyLevel(OWNER_LEVEL) {
    for (uint256 i = 0; i < _nextValidatorId; i++) {
      if (_validators[i] == validator) {
        delete _validators[i];
        break;
      }
    }
  }

  function approveSale(uint256 saleId) external override onlyLevel(OPERATOR_LEVEL) {
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
    address validator = ECDSA.recover(_hasher.encodeForSignature(saleId, setup, schedule, paymentToken), validatorSignature);
    require(isValidator(validator), "SaleFactory: invalid signature or modified params");
    Sale sale = new Sale(saleId, address(_saleData));
    address addr = address(sale);
    _saleData.setUpSale(saleId, addr, setup, schedule, paymentToken);
    emit NewSale(saleId, addr);
  }
}
