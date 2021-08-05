// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../utils/LevelAccess.sol";
import "./ISaleData.sol";
import "./ISaleFactory.sol";
import "./Sale.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is ISaleFactory, LevelAccess {
  uint256 public constant OPERATOR_LEVEL = 3;

  mapping(uint256 => bool) private _approvals;

  ISaleData private _saleData;

  mapping(uint => address) private _validators;
  uint private _nextValidatorId;

  constructor(address saleData, address[] memory validators) {
    _saleData = ISaleData(saleData);
    for (uint i = 0; i < validators.length; i++) {
      _validators[i] = validators[i];
    }
    _nextValidatorId = validators.length;
  }

  function addValidator(address newValidator) external override onlyLevel(OWNER_LEVEL) {
    require(!isValidator(newValidator), "SaleFactory: validator already set");
    _validators[_nextValidatorId++] = newValidator;
  }

  function isValidator(address validator) public override returns (bool){
    for (uint i = 0; i < _nextValidatorId; i++) {
      if(_validators[i] != validator) return true;
    }
    return false;
  }

  function revokeValidator(address validator) external override onlyLevel(OWNER_LEVEL) {
    for (uint i = 0; i < _nextValidatorId; i++) {
      if(_validators[i] == validator) {
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

  function revokeApproval(uint256 saleId) external override onlyLevel(OPERATOR_LEVEL) {
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
    address validator = ECDSA.recover(encodeForSignature(saleId, setup, schedule, paymentToken), validatorSignature);
    require(
      isValidator(validator),
      "SaleFactory: invalid signature or modified params"
    );
    Sale sale = new Sale(saleId, address(_saleData));
    address addr = address(sale);
    _saleData.grantManagerLevel(addr);
    sale.initialize(setup, schedule, paymentToken);
    emit NewSale(saleId, addr);
  }

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable.
  */

  function encodeForSignature(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    address paymentToken
  ) public view override returns (bytes32) {
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
    uint256[] memory steps = _saleData.packVestingSteps(schedule);
    uint256[11] memory data = [
    uint256(setup.pricingToken),
    uint256(setup.tokenListTimestamp),
    uint256(setup.remainingAmount),
    uint256(setup.minAmount),
    uint256(setup.capAmount),
    uint256(setup.pricingPayment),
    uint256(setup.tokenFeePercentage),
    uint256(setup.totalValue),
    uint256(setup.paymentToken),
    uint256(setup.paymentFeePercentage),
    uint256(setup.softCapPercentage)
    ];
    return
    keccak256(
      abi.encodePacked(
        "\x19\x00", /* EIP-191 */
        saleId,
        setup.sellingToken,
        setup.owner,
        steps,
        data,
        setup.isTokenTransferable,
        paymentToken
      )
    );
  }
}
