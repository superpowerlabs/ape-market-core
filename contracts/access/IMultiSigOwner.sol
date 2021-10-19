// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IMultiSigROwner
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A multisig owner to manage contracts
 */

interface IMultiSigOwner {
  event SignersUpdated(address[] signers, bool[] addRemoves);
  event ValidityUpdated(uint256 validity);

  function getSigners() external view returns (address[] memory);

  function getSignersByOrder(bytes32 order) external view returns (address[] memory);

  function quorum() external view returns (uint256);

  /**
   * @dev Update the list of the signers
   * @param signers An array of the signers to be added or removed
   * @param addRemoves An array to tell the contract if the signer must be add (true) or removed (false)
   * @param orderTimestamp The timestamp to check the validity of the order
   */
  function updateSigners(
    address[] memory signers,
    bool[] memory addRemoves,
    uint256 orderTimestamp
  ) external;

  /**
   * @dev Update the validity of the order
   * @param validity_ The new validity
   * @param orderTimestamp The timestamp to check the validity of the order
   */
  function updateValidity(uint256 validity_, uint256 orderTimestamp) external;
}
