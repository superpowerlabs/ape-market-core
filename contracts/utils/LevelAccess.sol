// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LevelAccess {

  event LevelSet(uint level, address account, address setter);

  uint public constant OWNER_LEVEL = 1;

  mapping(address => uint) public levels;
  mapping(uint => string) internal _revertMessages;

  modifier onlyLevel(uint level) {
    _checkLevel(level);
    _;
  }

  constructor () {
    levels[msg.sender] = OWNER_LEVEL;
    emit LevelSet(OWNER_LEVEL, msg.sender, address(0));
  }

  function _checkLevel(uint level) internal view {
    if (levels[msg.sender] != level) {
      if (bytes(_revertMessages[level]).length != 0) {
        revert(_revertMessages[level]);
      } else {
        revert("LevelAccess: caller not authorized.");
      }
    }
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
