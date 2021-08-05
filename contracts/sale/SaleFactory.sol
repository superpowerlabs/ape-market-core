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

  address private _factoryAdmin;
  address private _validator;

  constructor(address saleData, address validator) {
    _saleData = ISaleData(saleData);
    _validator = validator;
  }

  function updateValidator(address validator) external override onlyLevel(OWNER_LEVEL) {
    _validator = validator;
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
    require(
      ECDSA.recover(encodeForSignature(saleId, setup, schedule, paymentToken), validatorSignature) == _validator,
      "SaleFactory: invalid signature or modified params"
    );
    Sale sale = new Sale(saleId, address(_saleData));
    address addr = address(sale);
    _saleData.grantManagerLevel(addr);
    sale.initialize(setup, schedule, paymentToken);
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

  struct Setup {
    // 1st word:
    IERC20Min sellingToken;
    // 2nd word:
    address owner; // 160
    // pricingPayments and pricingToken builds a fraction to define the price of the token
    uint64 pricingToken;
    uint32 tokenListTimestamp;
    // 3rd word:
    uint120 remainingAmount; // selling token
    uint32 minAmount; // USD
    uint32 capAmount; // USD, it can be = totalValue (no cap to single investment)
    uint64 pricingPayment;
    uint8 tokenFeePercentage;
    // 4th word:
    address saleAddress;
    uint32 totalValue; // USD
    uint8 paymentToken; //
    uint8 paymentFeePercentage;
    uint8 softCapPercentage; // if 0, no soft cap
    // more 32 available
    bool isTokenTransferable;
  }

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
