// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/LevelAccess.sol";
import "./ISaleData.sol";

contract SaleData is ISaleData, LevelAccess {

  using SafeMath for uint;
  uint public constant MANAGER_LEVEL = 2;
  uint public constant ADMIN_LEVEL = 3;

  VestingStep[] private _vestingSchedule;
  Setup[] private _setups;

  function setUpSale(Setup memory setup, VestingStep[] memory schedule) external override
  onlyLevel(MANAGER_LEVEL) {
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(schedule[i].percentage > schedule[i - 1].percentage, "Sale: Vest percentage should be monotonic increasing");
      }
      _vestingSchedule.push(schedule[i]);
    }
    require(schedule[schedule.length - 1].percentage == 100, "Sale: Vest percentage should end at 100");
    _setups.push(setup);
  }

  function grantManagerLevel(address saleAddress) public override
  onlyLevel(ADMIN_LEVEL) {
    levels[saleAddress] = MANAGER_LEVEL;
    emit LevelSet(MANAGER_LEVEL, saleAddress, msg.sender);
  }

  function getVestedPercentage(Setup memory setup, VestingStep[] memory vs) public view override
  onlyLevel(MANAGER_LEVEL) returns (uint256) {
    if (setup.tokenListTimestamp == 0) {
      return 0;
    }
    uint256 vestedPercentage;
    for (uint256 i = 0; i < vs.length; i++) {
      uint256 ts = uint256(setup.tokenListTimestamp).add(vs[i].timestamp);
      if (ts > block.timestamp) {
        break;
      }
      vestedPercentage = vs[i].percentage;
    }
    return vestedPercentage;
  }

  function getVestedAmount(uint256 vestedPercentage, uint256 lastVestedPercentage, uint256 lockedAmount) public view override
  onlyLevel(MANAGER_LEVEL) returns (uint256) {
    uint256 vestedAmount;
    if (vestedPercentage == 100) {
      vestedAmount = lockedAmount;
    } else {
      vestedAmount = lockedAmount.mul(vestedPercentage.sub(lastVestedPercentage))
      .div(100 - lastVestedPercentage);
    }
    return vestedAmount;
  }

}