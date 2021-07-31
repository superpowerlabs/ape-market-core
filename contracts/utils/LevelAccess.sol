// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract LevelAccess {

  event LevelSet(uint256 level, address account, address setter);

  mapping(address => uint256) public levels;

  uint256 public constant OWNER_LEVEL = 1;

  modifier onlyLevel(uint256 level) {
    require(levels[msg.sender] == level, "LevelAccess: caller not authorized.");
    _;
  }

  constructor () {
    levels[msg.sender] = OWNER_LEVEL;
    emit LevelSet(OWNER_LEVEL, msg.sender, address(0));
  }

  function grantLevel(uint256 level, address addr) public
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
