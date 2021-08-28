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
  bytes32[] internal _contractsList;

  function register(string[] memory contractNames, address[] memory addrs) external override onlyOwner {
    require(contractNames.length == addrs.length, "ApeRegistry: contractNames and addresses are inconsistent");
    bool changesDone;
    for (uint256 i = 0; i < contractNames.length; i++) {
      bytes32 contractName = keccak256(abi.encodePacked(contractNames[i]));
      bool exists = _registry[contractName] != address(0);
      if (addrs[i] == address(0)) {
        if (exists) {
          delete _registry[contractName];
          for (uint256 j = 0; j < _contractsList.length; j++) {
            if (_contractsList[j] == contractName) {
              delete _contractsList[j];
            }
          }
          changesDone = true;
        }
      } else {
        _registry[contractName] = addrs[i];
        if (!exists) {
          _contractsList.push(contractName);
        }
        changesDone = true;
      }
      emit RegistryUpdated(contractNames[i], addrs[i]);
    }
  }

  function updateContracts(uint256 initialIndex, uint256 limit) public override onlyOwner {
    IRegistryUser registryUser;
    for (uint256 j = initialIndex; j < limit; j++) {
      if (_contractsList[j] != 0) {
        registryUser = IRegistryUser(_registry[_contractsList[j]]);
        registryUser.updateRegisteredContracts();
      }
    }
  }

  function updateAllContracts() external override onlyOwner {
    // this could go out of gas
    updateContracts(0, _contractsList.length);
  }

  function get(bytes32 contractName) external view override returns (address) {
    return _registry[contractName];
  }

  function get(string memory contractName) external view override returns (address) {
    return _registry[keccak256(abi.encodePacked(contractName))];
  }
}
