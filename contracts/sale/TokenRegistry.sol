// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/LevelAccess.sol";
import "./ITokenRegistry.sol";

contract TokenRegistry is ITokenRegistry, LevelAccess {
  uint256 public constant MANAGER_LEVEL = 1;

  mapping(uint8 => address) private _addressesById;
  mapping(address => uint8) private _idByAddress;

  uint8 private _nextId = 1;

  function nextIndex() public view virtual override returns (uint8) {
    return _nextId;
  }

  function addressById(uint8 id) public view virtual override returns (address) {
    return _addressesById[id];
  }

  function idByAddress(address addr) public view virtual override returns (uint8) {
    return _idByAddress[addr];
  }

  function addToken(address addr) public override onlyLevel(MANAGER_LEVEL) returns (uint8) {
    _addressesById[_nextId] = addr;
    _idByAddress[addr] = _nextId;
    emit TokenAdded(_nextId, addr);
    return _nextId++;
  }
}
