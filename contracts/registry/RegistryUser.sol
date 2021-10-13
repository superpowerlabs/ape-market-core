// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IApeRegistry.sol";
import "./IRegistryUser.sol";

// for debugging only
import "hardhat/console.sol";

contract RegistryUser is IRegistryUser, Ownable {
  IApeRegistry internal _registry;

  modifier onlyRegistry() {
    require(
      _msgSender() == address(_registry),
      string(abi.encodePacked("RegistryUser: only ApeRegistry can call this function"))
    );
    _;
  }

  constructor(address addr) {
    _registry = IApeRegistry(addr);
  }

  function _get(bytes32 contractHash) internal view returns (address) {
    return _registry.get(contractHash);
  }

  function updateRegistry(address addr) external override onlyOwner {
    // This is an emergency function. In theory,
    // there should not be any reason to update the registry
    _registry = IApeRegistry(addr);
  }

  // This must be overwritten by passive users.
  function updateRegisteredContracts() external virtual override {}
}
