// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenRegistry {
  event TokenAdded(uint8 id, address addr);

  function addressById(uint8 id) external view returns (address);

  function idByAddress(address addr) external view returns (uint8);

  function nextIndex() external view returns (uint8);

  function register(address addr) external returns (uint8);
}
