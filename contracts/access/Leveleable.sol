// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Leveleable {

  event LevelSet(uint level, address addr);

  mapping(address => uint) private _levels;

  modifier onlyLevel(uint level) {
    require(_levels[msg.sender] == level, "Leveleable: forbidden");
    _;
  }

  modifier onlyLevelFor(uint level, address addr) {
    require(_levels[addr] == level, "Leveleable: forbidden");
    _;
  }

  constructor () {
    _levels[msg.sender] = 1;
    emit LevelSet(1, msg.sender);
  }

  function grantLevel(uint level, address addr) public
  onlyLevel(1) {
    _levels[addr] = level;
    emit LevelSet(level, addr);
  }

  function revokeLevel(address addr) public
  onlyLevel(1) {
    delete _levels[addr];
    emit LevelSet(0, addr);
  }

  function getLevel(address addr) public view returns (uint) {
    return _levels[addr];
  }

  function hasLevel(uint level, address addr) public view returns (bool) {
    return _levels[addr] == level;
  }
}
