// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../registry/RegistryUser.sol";
import "../sale/ISaleData.sol";
import "./ITokenRegistry.sol";

contract TokenRegistry is ITokenRegistry, RegistryUser {
  bytes32 internal constant _SALE_DATA = keccak256("SaleData");

  mapping(uint8 => address) private _addressesById;
  mapping(address => uint8) private _idByAddress;

  uint8 private _nextId = 1;

  constructor(address registry) RegistryUser(registry) {}

  address private _saleDataAddress;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get(_SALE_DATA);
    if (addr != _saleDataAddress) {
      _saleDataAddress = addr;
    }
  }

  function nextIndex() public view virtual override returns (uint8) {
    return _nextId;
  }

  function addressById(uint8 id) public view virtual override returns (address) {
    return _addressesById[id];
  }

  function idByAddress(address addr) public view virtual override returns (uint8) {
    return _idByAddress[addr];
  }

  function register(address addr) public override returns (uint8) {
    // we do not check in addr == address(0) because this function can
    // be only called by the SaleData contract. The address has already
    // been verified somewhere else, here it is just stored
    require(_saleDataAddress == _msgSender(), "TokenRegistry: only SaleData can call this");
    _addressesById[_nextId] = addr;
    _idByAddress[addr] = _nextId;
    emit TokenAdded(_nextId, addr);
    // if called
    return _nextId++;
  }
}
