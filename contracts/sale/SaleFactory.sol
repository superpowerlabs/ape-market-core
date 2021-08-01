// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../utils/LevelAccess.sol";
import "./Sale.sol";
import "./ISaleData.sol";
import "./ISaleFactory.sol";

// for debugging only
import "hardhat/console.sol";

contract SaleFactory is ISaleFactory, LevelAccess {
  uint256 public constant OPERATOR_LEVEL = 3;

//  mapping(address => bool) private _sales;
//  mapping(uint256 => address) private _salesById;

  mapping(uint256 => bool) private _approvals;

  ISaleData private _saleData;

  address private _factoryAdmin;
  address private _validator;

  constructor(address saleDataAddress, address validator) {
    _saleData = ISaleData(saleDataAddress);
    _validator = validator;
  }

  function updateValidator(address validator) external override onlyLevel(OWNER_LEVEL) {
    _validator = validator;
  }

  function isLegitSale(address sale) external view override returns (bool) {
    return _saleData.isLegitSale(sale);
  }

  function approveSale(
    uint256 saleId
  ) external override onlyLevel(OPERATOR_LEVEL) {
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
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    bytes memory validatorSignature
  ) external override {
    require(
      ECDSA.recover(encodeForSignature(saleId, setup, schedule), validatorSignature) ==
        _validator,
      "SaleFactory: invalid signature or modified params"
    );
    Sale sale = new Sale(saleId, address(_saleData));
    address addr = address(sale);
    _saleData.grantManagerLevel(addr);
    sale.initialize(setup, schedule);
//    _salesById[saleId] = addr;
//    _sales[addr] = true;
    emit NewSale(saleId, addr);
  }

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable. We decided to
  use two arrays, one for the uint128 contained in VestingStep[], and one for the
  uint64 contained in Setup. Also, we skip the parameters that initially must be == 0.
  */
  function encodeForSignature(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule
  ) public pure override returns (bytes32) {
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
    uint128[] memory steps = new uint128[](schedule.length * 2);
    uint256 j = 0;
    for (uint8 i = 0; i < schedule.length; i++) {
      steps[j++] = schedule[i].timestamp;
      steps[j++] = schedule[i].percentage;
    }
    uint64[7] memory data = [
      setup.minAmount,
      setup.capAmount,
      setup.pricingToken,
      setup.pricingPayment,
      setup.tokenListTimestamp,
      setup.tokenFeePercentage,
      setup.paymentFeePercentage
    ];
    return
      keccak256(
        abi.encodePacked(
          "\x19\x00", /* EIP-191 */
          saleId,
          setup.satoken,
          setup.sellingToken,
          setup.paymentToken,
          setup.owner,
          steps,
          data,
          setup.isTokenTransferable
        )
      );
  }
}
