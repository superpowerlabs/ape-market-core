// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISATokenData {
  struct SA {
    address sale;
    uint256 remainingAmount;
    uint128 vestedPercentage;
  }
}
