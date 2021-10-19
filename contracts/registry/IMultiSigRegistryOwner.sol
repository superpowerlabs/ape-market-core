// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IMultiSigRegistryOwner
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A multisig manager for the ApeRegistry
 */

interface IMultiSigRegistryOwner {
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
  ) external;

  function getOrderHash(
    bytes32[] memory contractHashes,
    address[] memory addresses,
    uint256 orderTimestamp
  ) external pure returns (bytes32);

  // function that do not require more than one signer

  function updateContracts(uint256 initialIndex, uint256 limit) external;

  function updateAllContracts() external;
}
