// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IApeRegistry {
  function set(bytes32[] memory contractNames, address[] memory addrs) external;

  function get(bytes32 memory contractName) external view returns (address);

}
