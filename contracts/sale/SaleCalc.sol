// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISale.sol";

contract SaleCalc {

  using SafeMath for uint;

  function getVestedPercentage(ISale.Setup memory setup, ISale.VestingStep[] memory vs) public view returns (uint256) {
    if (setup.tokenListTimestamp == 0) {// token not listed yet!
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

  function getVestedAmount(
    uint256 vestedPercentage,
    uint256 lastVestedPercentage,
    uint256 lockedAmount) public pure returns (uint256) {

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