// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleSetupHasher {

  function encodeForSignature(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    address paymentToken
  ) external view returns (bytes32);
}
