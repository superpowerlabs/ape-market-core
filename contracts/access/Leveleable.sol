// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Leveleable {

  event LevelSet(uint level, address addr);

  mapping(address => uint) public levels;

  modifier onlyLevel(uint level) {
    require(levels[msg.sender] == level, "Leveleable: forbidden");
    _;
  }

  modifier onlyLevelFor(uint level, address addr) {
    require(levels[addr] == level, "Leveleable: forbidden");
    _;
  }

  constructor () {
    levels[msg.sender] = 1;
    emit LevelSet(1, msg.sender);
  }

  function grantLevel(uint level, address addr) public
  onlyLevel(1) {
    levels[addr] = level;
    emit LevelSet(level, addr);
  }

  function revokeLevel(address addr) public
  onlyLevel(1) {
    delete levels[addr];
    emit LevelSet(0, addr);
  }

}
