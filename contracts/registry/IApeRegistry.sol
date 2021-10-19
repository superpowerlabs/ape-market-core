// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IApeRegistry {
  event RegistryUpdated(bytes32 contractHash, address addr);
  event ChangePushedToSubscribers();

  function register(bytes32[] memory contractHashes, address[] memory addrs) external;

  function get(bytes32 contractHash) external view returns (address);

  function updateContracts(uint256 initialIndex, uint256 limit) external;

  function updateAllContracts() external;
}
