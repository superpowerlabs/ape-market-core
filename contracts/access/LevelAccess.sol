// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LevelAccess {

  event LevelSet(uint level, address account, address setter);

  mapping(address => uint) public levels;

  modifier onlyLevel(uint level) {
    require(levels[msg.sender] == level, "LevelAccess: forbidden");
    _;
  }

  modifier onlyLevelFor(uint level, address addr) {
    require(levels[addr] == level, "LevelAccess: forbidden");
    _;
  }

  constructor () {
    levels[msg.sender] = 1;
    emit LevelSet(1, msg.sender, address(0));
  }

  function grantLevel(uint level, address addr) public
  onlyLevel(1) {
    levels[addr] = level;
    emit LevelSet(level, addr, msg.sender);
  }

  function revokeLevel(address addr) public
  onlyLevel(1) {
    delete levels[addr];
    emit LevelSet(0, addr, msg.sender);
  }

}
