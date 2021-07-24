// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// this contract is to test and do calculations

contract Debug {

  struct VestingStep {
    uint256 timestamp;
    uint256 percentage;
  }

  struct VestingStep2 {
    uint128 timestamp;
    uint128 percentage;
  }

  VestingStep[] _vestingSchedule;
  VestingStep2[] _vestingSchedule2;

  struct Setup {
    address satoken;
    address sellingToken;
    address paymentToken;
    address owner;
    uint256 remainingAmount;
    uint256 minAmount;
    uint256 capAmount;
    uint256 pricingToken;
    uint256 pricingPayment;
    uint256 tokenListTimestamp;
    uint256 tokenFeePercentage;
    uint256 paymentFeePercentage;
    bool isTokenTransferable;
  }

  struct Setup2 {
    address satoken;
    address sellingToken;
    address paymentToken;
    address owner;
    uint256 remainingAmount;
    uint64 minAmount;
    uint64 capAmount;
    uint64 pricingToken;
    uint64 pricingPayment;
    uint64 tokenListTimestamp;
    uint64 tokenFeePercentage;
    uint64 paymentFeePercentage;
    bool isTokenTransferable;
  }

  Setup private _setup;
  Setup2 private _setup2;

  bool private _notTransferable;

  function setSetup(Setup memory setup_) external {
    _setup = setup_;
  }

  function setSetup2(Setup2 memory setup_) external {
    _setup2 = setup_;
  }

  function setVesting(VestingStep[] memory schedule) external {
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(schedule[i].percentage > schedule[i - 1].percentage, "Sale: Vest percentage should be monotonic increasing");
      }
      _vestingSchedule.push(schedule[i]);
    }
  }

  function setVesting2(VestingStep2[] memory schedule) external {
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(schedule[i].percentage > schedule[i - 1].percentage, "Sale: Vest percentage should be monotonic increasing");
      }
      _vestingSchedule2.push(schedule[i]);
    }
  }

  function transferability(bool isTokenTransferable) external {
    if (_setup.isTokenTransferable != isTokenTransferable) {
      _setup.isTokenTransferable = isTokenTransferable;
    }
  }

  function transferability2(bool isTokenTransferable) external {
    if (_setup2.isTokenTransferable != isTokenTransferable) {
      _setup2.isTokenTransferable = isTokenTransferable;
    }
  }

}
