// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LevelAccess {

  event LevelSet(uint level, address account, address setter);

  uint public constant OWNER_LEVEL = 1;

  mapping(address => uint) public levels;

  modifier onlyLevel(uint level) {
    require(levels[msg.sender] == level, "LevelAccess: access forbidden");
    _;
  }

  constructor () {
    levels[msg.sender] = OWNER_LEVEL;
    emit LevelSet(OWNER_LEVEL, msg.sender, address(0));
  }

  function grantLevel(uint level, address addr) public
  onlyLevel(OWNER_LEVEL) {
    levels[addr] = level;
    emit LevelSet(level, addr, msg.sender);
  }

  function revokeLevel(address addr) public
  onlyLevel(OWNER_LEVEL) {
    delete levels[addr];
    emit LevelSet(0, addr, msg.sender);
  }

}