// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../access/MultiSigOwner.sol";

contract MultiSigOwnerMock is MultiSigOwner {

  constructor(
    address[] memory signersList_,
    uint256 validity_
  ) MultiSigOwner(signersList_, validity_) {}

  function getSignersOrder(
    address[] memory signers,
    bool[] memory addRemoves,
    uint256 orderTimestamp
  ) external pure returns (bytes32) {
    return keccak256(abi.encodePacked(signers, addRemoves, orderTimestamp));
  }

  function getValidityOrder(uint256 validity_, uint256 orderTimestamp) external pure returns (bytes32) {
    return keccak256(abi.encodePacked(validity_, orderTimestamp));
  }

}
