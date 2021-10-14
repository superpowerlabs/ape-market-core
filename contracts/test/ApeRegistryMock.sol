// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ApeRegistryMock {
  address public multiSigOwner;

  event RegisterTriggered();
  event UpdateContractsTriggered();
  event UpdateAllContractsTriggered();

  modifier onlyMultiSigOwner() {
    require(msg.sender == multiSigOwner, "ApeRegistry: not the owner");
    _;
  }

  function setMultiSigOwner(address addr) external {
    multiSigOwner = addr;
  }

  function register(bytes32[] memory contractHashes, address[] memory addrs) external onlyMultiSigOwner {}

  function updateContracts(uint256 initialIndex, uint256 limit) public onlyMultiSigOwner {}

  function updateAllContracts() external onlyMultiSigOwner {}
}
