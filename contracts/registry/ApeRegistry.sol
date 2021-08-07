// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ApeRegistry
 * @version 1.0.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A registry for all Ape contracts
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IApeRegistry.sol";

contract ApeRegistry is IApeRegistry, Ownable {
  event RegistryUpdated(string contractName, address addr);

  mapping(bytes32 => address) internal _registry;

  function set(string[] memory contractNames, address[] memory addrs) external override onlyOwner {
    require(contractNames.length == addrs.length, "ApeRegistry: contractNames and addresses are inconsistent");
    for (uint256 i = 0; i < contractNames.length; i++) {
      bytes32 contractName = keccak256(abi.encodePacked(contractNames[i]));
      if (addrs[i] == address(0)) {
        delete _registry[contractName];
      } else {
        _registry[contractName] = addrs[i];
      }
      emit RegistryUpdated(contractNames[i], addrs[i]);
    }
  }

  function get(bytes32 contractName) external view override returns (address) {
    return _registry[contractName];
  }
}
