// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleDB.sol";
import "../registry/RegistryUser.sol";

contract SaleDB is ISaleDB, RegistryUser {
  uint16 private _nextId = 1;

  mapping(uint16 => Setup) private _setups;
  mapping(address => uint16) private _saleIdByAddress;
  mapping(uint16 => uint256[]) private _extraVestingSteps;

  mapping(uint16 => mapping(address => uint32)) private _approvedAmounts;
  mapping(uint16 => mapping(address => uint32)) private _valuesInEscrow;

  modifier onlySaleData() {
    require(_msgSender() == _saleDataAddress, "SaleBD: only SaleData can call this function");
    _;
  }

  constructor(address registry) RegistryUser(registry) {}

  address private _saleDataAddress;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get("SaleData");
    if (_saleDataAddress != addr) {
      _saleDataAddress = addr;
    }
  }

  function nextSaleId() external view override returns (uint256) {
    return _nextId;
  }

  function increaseSaleId() external override onlySaleData {
    _nextId++;
  }

  function getSaleIdByAddress(address saleAddress) external view override returns (uint16) {
    return uint16(_saleIdByAddress[saleAddress]);
  }

  function getSaleAddressById(uint16 saleId) external view override returns (address) {
    return _setups[saleId].saleAddress;
  }

  function initSale(
    uint16 saleId,
    Setup memory setup,
    uint256[] memory extraVestingSteps
  ) external override onlySaleData {
    require(_setups[saleId].owner == address(0), "SaleDB: saleId has already been used");
    require(saleId < _nextId, "SaleDB: invalid saleId");
    _setups[saleId] = setup;
    _saleIdByAddress[setup.saleAddress] = saleId;
    _extraVestingSteps[saleId] = extraVestingSteps;
  }

  function triggerTokenListing(uint16 saleId) external virtual override onlySaleData {
    require(_setups[saleId].tokenListTimestamp == 0, "SaleData: token already listed");
    _setups[saleId].tokenListTimestamp = uint32(block.timestamp);
  }

  function addToRemainingAmount(uint16 saleId, uint120 amount) external virtual override onlySaleData {
    _setups[saleId].remainingAmount = _setups[saleId].remainingAmount + amount;
  }

  function increaseRemainingAmount(uint16 saleId, uint120 extraAmount) external virtual override onlySaleData {
    _setups[saleId].remainingAmount = _setups[saleId].remainingAmount + extraAmount;
  }

  function makeTransferable(uint16 saleId) external override onlySaleData {
    if (!_setups[saleId].isTokenTransferable) {
      _setups[saleId].isTokenTransferable = true;
    }
  }

  function getSetupById(uint16 saleId) external view override returns (Setup memory) {
    return _setups[saleId];
  }

  function getExtraVestingStepsById(uint16 saleId) external view override returns (uint256[] memory) {
    return _extraVestingSteps[saleId];
  }

  function setApproval(
    uint16 saleId,
    address investor,
    uint32 amount
  ) external virtual override onlySaleData {
    _approvedAmounts[saleId][investor] = amount;
  }

  function deleteApproval(uint16 saleId, address investor) external virtual override onlySaleData {
    delete _approvedAmounts[saleId][investor];
  }

  function getApproval(uint16 saleId, address investor) external virtual override returns (uint256) {
    return _approvedAmounts[saleId][investor];
  }
}
