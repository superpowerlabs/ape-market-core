// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./ISaleFactory.sol";
import "./ISaleDB.sol";
import "./Sale.sol";
import "../registry/RegistryUser.sol";

import {SaleLib} from "../libraries/SaleLib.sol";

contract SaleFactory is ISaleFactory, RegistryUser {
  bytes32 internal constant _SALE_DATA = keccak256("SaleData");
  bytes32 internal constant _SALE_DB = keccak256("SaleDB");

  mapping(bytes32 => uint16) private _setupHashes;
  mapping(address => bool) private _operators;

  modifier onlyOperator() {
    require(isOperator(_msgSender()), "SaleFactory: only operators can call this function");
    _;
  }

  constructor(address registry, address operator) RegistryUser(registry) {
    setOperator(operator, true);
  }

  ISaleData private _saleData;
  ISaleDB private _saleDB;

  function getSaleIdBySetupHash(bytes32 hash) external view virtual override returns (uint16) {
    return _setupHashes[hash];
  }

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get(_SALE_DATA);
    if (addr != address(_saleData)) {
      _saleData = ISaleData(addr);
    }
    addr = _get(_SALE_DB);
    if (addr != address(_saleDB)) {
      _saleDB = ISaleDB(addr);
    }
  }

  function setOperator(address operator, bool isOperator_) public override onlyOwner {
    if (!isOperator_ && _operators[operator]) {
      delete _operators[operator];
      emit OperatorUpdated(operator, false);
    } else if (isOperator_ && !_operators[operator]) {
      _operators[operator] = true;
      emit OperatorUpdated(operator, true);
    }
  }

  function isOperator(address operator) public view override returns (bool) {
    return _operators[operator];
  }

  function approveSale(bytes32 setupHash) external override onlyOperator {
    uint16 saleId = _saleDB.nextSaleId();
    _saleData.increaseSaleId();
    _setupHashes[setupHash] = saleId;
    emit SaleApproved(saleId);
  }

  function revokeSale(bytes32 setupHash) external override onlyOperator {
    delete _setupHashes[setupHash];
    emit SaleRevoked(_setupHashes[setupHash]);
  }

  function newSale(
    uint16 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external override {
    bytes32 setupHash = SaleLib.packAndHashSaleConfiguration(setup, extraVestingSteps, paymentToken);
    require(saleId != 0, "SaleFactory: sale not approved");
    require(_setupHashes[setupHash] == saleId, "SaleFactory: modified sale params");
    if (setup.futureTokenSaleId != 0) {
      ISaleDB.Setup memory futureTokenSetup = _saleData.getSetupById(setup.futureTokenSaleId);
      require(futureTokenSetup.isFutureToken, "SaleFactory: futureTokenSaleId does not point to a future Token sale");
      require(futureTokenSetup.totalValue == setup.totalValue, "SaleFactory: token value mismatch");
    }
    Sale sale = new Sale(saleId, address(registry));
    address addr = address(sale);
    _saleData.setUpSale(saleId, addr, setup, extraVestingSteps, paymentToken);
    delete _setupHashes[setupHash];
    emit NewSale(saleId, addr);
  }
}
