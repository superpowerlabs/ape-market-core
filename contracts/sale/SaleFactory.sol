// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleSetupHasher.sol";
import "./ISaleFactory.sol";
import "./ISaleDB.sol";
import "./Sale.sol";
import "../registry/RegistryUser.sol";

contract SaleFactory is ISaleFactory, RegistryUser {

  bytes32 internal constant _SALE_DATA = keccak256("SaleData");
  bytes32 internal constant _SALE_SETUP_HASHER = keccak256("SaleSetupHasher");
  bytes32 internal constant _SALE_DB = keccak256("SaleDB");

  mapping(bytes32 => uint16) private _setupHashes;
  mapping(address => uint256) private _operators;

  uint256 public constant OPERATOR = 1;

  modifier onlyOperator(uint256 roles) {
    require(isOperator(_msgSender(), roles), "SaleFactory: only operators can call this function");
    _;
  }

  constructor(
    address registry,
    address[] memory operators,
    uint256[] memory roles
  ) RegistryUser(registry) {
    for (uint256 i = 0; i < operators.length; i++) {
      updateOperators(operators[i], roles[i]);
    }
  }

  ISaleData private _saleData;
  ISaleSetupHasher private _saleSetupHasher;
  ISaleDB private _saleDB;

  function getSaleIdBySetupHash(bytes32 hash) virtual override external view returns(uint16)  {
    return _setupHashes[hash];
  }

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get(_SALE_DATA);
    if (addr != address(_saleData)) {
      _saleData = ISaleData(addr);
    }
    addr = _get(_SALE_SETUP_HASHER);
    if (addr != address(_saleSetupHasher)) {
      _saleSetupHasher = ISaleSetupHasher(addr);
    }
    addr = _get(_SALE_DB);
    if (addr != address(_saleDB)) {
      _saleDB = ISaleDB(addr);
    }
  }

  function updateOperators(address operator, uint256 role) public override onlyOwner {
    if (role == 0) {
      delete _operators[operator];
    } else {
      _operators[operator] = role;
    }
    emit OperatorUpdated(operator, role);
  }

  function isOperator(address operator, uint256 role) public view override returns (bool) {
    return _operators[operator] & role != 0;
  }

  function approveSale(bytes32 setupHash) external override onlyOperator(OPERATOR) {
    uint16 saleId = _saleDB.nextSaleId();
    _saleData.increaseSaleId();
    _setupHashes[setupHash] = saleId;
    emit SaleApproved(saleId);
  }

  function revokeSale(bytes32 setupHash) external override onlyOperator(OPERATOR) {
    delete _setupHashes[setupHash];
    emit SaleRevoked(_setupHashes[setupHash]);
  }

  function newSale(
    uint16 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external override {
    bytes32 setupHash = _saleSetupHasher.packAndHashSaleConfiguration(setup, extraVestingSteps, paymentToken);
    require(saleId != 0 && _setupHashes[setupHash] == saleId,
      "SaleFactory: non approved sale or modified params");
    Sale sale = new Sale(saleId, address(_registry));
    address addr = address(sale);
    _saleData.setUpSale(saleId, addr, setup, extraVestingSteps, paymentToken);
    delete _setupHashes[setupHash];
    emit NewSale(saleId, addr);
  }
}
