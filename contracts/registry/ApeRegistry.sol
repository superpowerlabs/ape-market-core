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
import "./IRegistryUser.sol";

contract ApeRegistry is IApeRegistry, Ownable {
  event RegistryUpdated(string contractName, address addr);

  mapping(bytes32 => address) internal _registry;
  bytes32[] internal _index;

  function register(string[] memory contractNames, address[] memory addrs) external override onlyOwner {
    require(contractNames.length == addrs.length, "ApeRegistry: contractNames and addresses are inconsistent");
    bool changesDone;
    for (uint256 i = 0; i < contractNames.length; i++) {
      bytes32 contractName = keccak256(abi.encodePacked(contractNames[i]));
      bool exists = _registry[contractName] != address(0);
      if (addrs[i] == address(0)) {
        if (exists) {
          delete _registry[contractName];
          for (uint256 j = 0; j < _index.length; j++) {
            if (_index[j] == contractName) {
              delete _index[j];
            }
          }
          changesDone = true;
        }
      } else {
        _registry[contractName] = addrs[i];
        if (!exists) {
          _index.push(contractName);
        }
        changesDone = true;
      }
      emit RegistryUpdated(contractNames[i], addrs[i]);
    }
  }

  function updateContracts(uint256 initialIndex, uint256 limit) public override onlyOwner {
    IRegistryUser registryUser;
    for (uint256 j = initialIndex; j < limit; j++) {
      if (_index[j] != 0) {
        registryUser = IRegistryUser(_registry[_index[j]]);
        registryUser.updateRegisteredContracts();
      }
    }
  }

  function updateAllContracts() external override onlyOwner {
    // this could go out of gas
    updateContracts(0, _index.length);
  }

  function get(bytes32 contractName) external view override returns (address) {
    return _registry[contractName];
  }
}
