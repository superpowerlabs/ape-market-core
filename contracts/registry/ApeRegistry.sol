// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ApeRegistry
 * @version 1.1.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A registry for all Ape contracts
 */

//import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IApeRegistry.sol";
import "./IRegistryUser.sol";
import "../access/OwnedByMultiSigOwner.sol";

contract ApeRegistry is IApeRegistry, OwnedByMultiSigOwner {
  mapping(bytes32 => address) internal _registry;
  bytes32[] internal _contractsList;

  function register(bytes32[] memory contractHashes, address[] memory addrs) external override onlyMultiSigOwner {
    require(contractHashes.length == addrs.length, "ApeRegistry: contractHashes and addresses are inconsistent");
    bool changesDone;
    for (uint256 i = 0; i < contractHashes.length; i++) {
      bytes32 contractHash = contractHashes[i];
      bool exists = _registry[contractHash] != address(0);
      if (addrs[i] == address(0)) {
        if (exists) {
          delete _registry[contractHash];
          for (uint256 j = 0; j < _contractsList.length; j++) {
            if (_contractsList[j] == contractHash) {
              _contractsList[j] = _contractsList[_contractsList.length - 1];
              _contractsList.pop();
              break;
            }
          }
          changesDone = true;
        }
      } else {
        _registry[contractHash] = addrs[i];
        if (!exists) {
          _contractsList.push(contractHash);
        }
        changesDone = true;
      }
      if (changesDone) {
        emit RegistryUpdated(contractHashes[i], addrs[i]);
      }
    }
    if (changesDone && !_requiresMultiSigOwner) {
      // at this initial step, there is no risk of going out of gas
      updateAllContracts();
      // after setting the following, only the multiSigOwner can make changes
      _requiresMultiSigOwner = true;
    }
  }

  function updateContracts(uint256 initialIndex, uint256 limit) public override onlyMultiSigOwner {
    IRegistryUser registryUser;
    bool done;
    for (uint256 j = initialIndex; j < limit; j++) {
      if (_contractsList[j] != 0) {
        registryUser = IRegistryUser(_registry[_contractsList[j]]);
        registryUser.updateRegisteredContracts();
        done = true;
      }
    }
    if (done) {
      emit ChangePushedToSubscribers();
    }
  }

  function updateAllContracts() public override onlyMultiSigOwner {
    // this could go out of gas
    updateContracts(0, _contractsList.length);
  }

  function get(bytes32 contractHash) external view override returns (address) {
    return _registry[contractHash];
  }
}
