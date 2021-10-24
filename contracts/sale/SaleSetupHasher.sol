// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleSetupHasher.sol";
import "../registry/FakeRegistryUser.sol";

import {SaleLib} from "../libraries/SaleLib.sol";

contract SaleSetupHasher is ISaleSetupHasher, FakeRegistryUser {
  function validateAndPackVestingSteps(ISaleDB.VestingStep[] memory vestingStepsArray)
    external
    pure
    override
    returns (uint256[] memory)
  {
    return SaleLib.validateAndPackVestingSteps(vestingStepsArray);
  }

  function calculateVestedPercentage(
    uint256 vestingSteps,
    uint256[] memory extraVestingSteps,
    uint256 tokenListTimestamp,
    uint256 currentTimestamp
  ) external pure override returns (uint8) {
    return SaleLib.calculateVestedPercentage(vestingSteps, extraVestingSteps, tokenListTimestamp, currentTimestamp);
  }

  function packAndHashSaleConfiguration(
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external pure override returns (bytes32) {
    return SaleLib.packAndHashSaleConfiguration(setup, extraVestingSteps, paymentToken);
  }
}
