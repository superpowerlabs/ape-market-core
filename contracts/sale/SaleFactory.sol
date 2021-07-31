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

  event NewSale(address saleAddress);

  uint256 public constant FACTORY_ADMIN_LEVEL = 3;

  mapping(address => bool) private _sales;
  mapping(uint256 => address) private _salesById;
  mapping(uint => bytes) private _approvals;

  ISaleData private _saleData;

  address private _factoryAdmin;
  address private _validator;

  constructor(address saleDataAddress, address validator){
    _saleData = ISaleData(saleDataAddress);
    _validator = validator;
  }

  function updateValidator(address validator) external override onlyLevel(OWNER_LEVEL) {
    _validator = validator;
  }

  function isLegitSale(address sale) external view override returns (bool) {
    return _sales[sale];
  }

  function getSaleAddressById(uint256 i) external view override returns (address) {
    return _salesById[i];
  }

  function approveSale(uint saleId, bytes memory signature) external override
  onlyLevel(FACTORY_ADMIN_LEVEL) {
    require(saleId == _saleData.nextSaleId(), "SaleFactory: invalid sale id");
    _saleData.increaseSaleId();
    _approvals[saleId] = signature;
  }

  function revokeApproval(uint saleId) external override
  onlyLevel(FACTORY_ADMIN_LEVEL) {
    delete _approvals[saleId];
  }

  function newSale(
    uint saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule
  ) external override {
    require(
      ECDSA.recover(
        encodeForSignature(saleId, setup, schedule),
        _approvals[saleId]
      ) == _validator, "SaleFactory: invalid signature or modified params");
    Sale sale = new Sale(saleId, address(_saleData));
    address addr = address(sale);
    _saleData.grantManagerLevel(addr);
    sale.initialize(setup, schedule);
    _salesById[saleId] = addr;
    _sales[addr] = true;
    emit NewSale(addr);
  }

  function _packVestingStep(ISaleData.VestingStep[] memory schedule) internal pure
  returns (uint128[] memory) {
    uint128[] memory steps = new uint128[](schedule.length * 2);
    uint j = 0;
    for (uint8 i = 0; i < schedule.length; i++) {
      steps[j++] = schedule[i].timestamp;
      steps[j++] = schedule[i].percentage;
    }
    return steps;
  }

  function _packUint64sInSetup(ISaleData.Setup memory setup) internal pure
  returns (uint64[] memory) {
    uint64[] memory data = new uint64[](7);
    uint j = 0;
    data[j++] = setup.minAmount;
    data[j++] = setup.capAmount;
    data[j++] = setup.pricingToken;
    data[j++] = setup.pricingPayment;
    data[j++] = setup.tokenListTimestamp;
    data[j++] = setup.tokenFeePercentage;
    data[j++] = setup.paymentFeePercentage;
    return data;
  }

  function encodeForSignature(
    uint saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule
  ) public pure override returns (bytes32){
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
    uint128[] memory steps = _packVestingStep(schedule);
    uint64[] memory data = _packUint64sInSetup(setup);
    return keccak256(
      abi.encodePacked(
        "\x19\x00"/* EIP-191 */,
        saleId,
        setup.satoken,
        setup.sellingToken,
        setup.paymentToken,
        setup.owner,
        steps,
        data,
        setup.isTokenTransferable
      ));
  }

}
