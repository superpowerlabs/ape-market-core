// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IApeRegistry.sol";

contract RegistryUser is Ownable {
  IApeRegistry internal _registry;
  address internal _owner;

  modifier onlyFrom(string memory contractName) {
    require(
      _msgSender() == _get(contractName),
      string(abi.encodePacked("RegistryUser: only ", contractName, " can call this function"))
    );
    _;
  }

  constructor(address addr) {
    _registry = IApeRegistry(addr);
  }

  function _get(string memory contractName) internal view returns (address) {
    return _registry.get(keccak256(abi.encodePacked(contractName)));
  }

  function updateRegistry(address addr) external onlyOwner {
    // This is an emergency function. In theory,
    // there should not be any reason to update the registry
    _registry = IApeRegistry(addr);
  }
}
