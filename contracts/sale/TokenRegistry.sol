// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../registry/ApeRegistryAPI.sol";
import "./ITokenRegistry.sol";

contract TokenRegistry is ITokenRegistry, ApeRegistryAPI {

  mapping(uint8 => address) private _addressesById;
  mapping(address => uint8) private _idByAddress;

  uint8 private _nextId = 1;

  constructor(address registry_) ApeRegistryAPI(registry_){}

  function nextIndex() public view virtual override returns (uint8) {
    return _nextId;
  }

  function addressById(uint8 id) public view virtual override returns (address) {
    return _addressesById[id];
  }

  function idByAddress(address addr) public view virtual override returns (uint8) {
    return _idByAddress[addr];
  }

  function addToken(address addr) public override onlyFrom("SaleData") returns (uint8) {
    _addressesById[_nextId] = addr;
    _idByAddress[addr] = _nextId;
    emit TokenAdded(_nextId, addr);
    return _nextId++;
  }
}
