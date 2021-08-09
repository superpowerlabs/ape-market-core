// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IApeRegistry {
  function register(string[] memory contractNames, address[] memory addrs) external;

  function get(bytes32 contractName) external view returns (address);
}
