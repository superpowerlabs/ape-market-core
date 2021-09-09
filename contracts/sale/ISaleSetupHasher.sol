// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleDB.sol";

interface ISaleSetupHasher {
  function validateAndPackVestingSteps(ISaleDB.VestingStep[] memory vestingStepsArray)
    external
    pure
    returns (uint256[] memory, string memory);

  function packAndHashSaleConfiguration(
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external pure returns (bytes32);
}
