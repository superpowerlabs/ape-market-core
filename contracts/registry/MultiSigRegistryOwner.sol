// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiSigRegistryOwner
 * @version 1.0.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A multisig manager for the ApeRegistry
 */

import "@openzeppelin/contracts/utils/Context.sol";
import "./IApeRegistry.sol";
import "../access/MultiSigOwner.sol";
import "./IMultiSigRegistryOwner.sol";

contract MultiSigRegistryOwner is IMultiSigRegistryOwner, MultiSigOwner {
  IApeRegistry private _apeRegistry;

  constructor(
    address apeRegistry,
    address[] memory signersList_,
    uint256 validity_
  ) MultiSigOwner(signersList_, validity_) {
    _apeRegistry = IApeRegistry(apeRegistry);
  }

  /**
   * @dev Register/updates contracts
   * @param contractHashes The ids of the contracts
   * @param addresses The addresses of the contracts
   * @param orderTimestamp Identifies the operation and must be passed by any signers and since
   *                       then there is a validity period to complete the execution
   */
  function register(
    bytes32[] memory contractHashes,
    address[] memory addresses,
    uint256 orderTimestamp
  ) external override onlyValidOrder(orderTimestamp) onlySigner {
    bytes32 order = getOrderHash(contractHashes, addresses, orderTimestamp);
    if (_orderIsReadyForExecution(order)) {
      _apeRegistry.register(contractHashes, addresses);
    }
  }

  function getOrderHash(
    bytes32[] memory contractHashes,
    address[] memory addresses,
    uint256 orderTimestamp
  ) public pure override returns (bytes32) {
    return keccak256(abi.encodePacked(contractHashes, addresses, orderTimestamp));
  }

  // function that do not require more than one signer

  function updateContracts(uint256 initialIndex, uint256 limit) external override onlySigner {
    _apeRegistry.updateContracts(initialIndex, limit);
  }

  function updateAllContracts() external override onlySigner {
    _apeRegistry.updateAllContracts();
  }
}
