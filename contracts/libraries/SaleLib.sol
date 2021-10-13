// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../sale/ISaleDB.sol";

library SaleLib {
  /**
   * @dev Validate and pack a VestingStep[]. It must be called by the dApp during the configuration of the Sale setup. The same code can be executed in Javascript, but running a function on a smart contract guarantees future compatibility.
   * @param vestingStepsArray The array of VestingStep

   A single ISaleDB.VestingStep is an object like:

   {
    "waitTime": 30,     // 30 days
    "percentage": 15    // 15%
  }

   Putting the data in the blockchain would be very expensive for vesting schedules with many steps.
   Consider the following edge case (taken from our tests):

   ISaleDB.VestingStep[] memory steps = [
    {"waitTime":10,"percentage":1},{"waitTime":20,"percentage":2}, {"waitTime":30,"percentage":3},
    {"waitTime":40,"percentage":4},{"waitTime":50,"percentage":5},
    {"waitTime":60,"percentage":6},{"waitTime":70,"percentage":7},{"waitTime":80,"percentage":8},
    {"waitTime":90,"percentage":9},{"waitTime":100,"percentage":10},{"waitTime":110,"percentage":11},
    {"waitTime":120,"percentage":12},{"waitTime":130,"percentage":13},{"waitTime":140,"percentage":14},
    {"waitTime":150,"percentage":15},{"waitTime":160,"percentage":16},{"waitTime":170,"percentage":17},
    {"waitTime":180,"percentage":18},{"waitTime":190,"percentage":19},{"waitTime":200,"percentage":20},
    {"waitTime":210,"percentage":21},{"waitTime":220,"percentage":22},{"waitTime":230,"percentage":23},
    {"waitTime":240,"percentage":24},{"waitTime":250,"percentage":25},{"waitTime":260,"percentage":26},
    {"waitTime":270,"percentage":27},{"waitTime":280,"percentage":28},{"waitTime":290,"percentage":29},
    {"waitTime":300,"percentage":30},{"waitTime":310,"percentage":31},{"waitTime":320,"percentage":32}
  ]

  Saving it in a mapping(uint => VestingStep) would cost a lot of gas, with the risk of going out of gas.

  The idea is to pack steps in uint256. In the case above, we would get
  the following array, which would cost only 3 words.

    [
      "11010010009009008008007007006006005005004004003003002002001001000",
      "22021021020020019019018018017017016016015015014014013013012012011",
      "32031031030030029029028028027027026026025025024024023023022"
    ]

  For better optimization, the first element of the array is saved in the sale
  setup struct (ISaleDB.Setup)), because it is mandatory. The remaining 3
  elements would be saved in the _extraVestingSteps array.

  Look at the first uint256 in the array above. It can be seen as

  011010 010009 009008 008007 007006 006005 005004 004003 003002 002001 001000

  where any element is composed by a composition of 4 digits for the number of days,
  and 2 digits for the percentage. The percentage is diminished by 1 because
  it can never be zero. So, for example, the VestingStep

    {
      "waitTime": 300,
      "percentage": 50
    }

  becomes 300 days * 100 + (50% - 1) = 030049

  We can pack 11 vesting steps in a single uint256

   */

  function validateAndPackVestingSteps(ISaleDB.VestingStep[] memory vestingStepsArray)
    internal
    pure
    returns (uint256[] memory, string memory)
  {
    // the number 11 is because we can pack at most 11 steps in a single uint256
    uint256 len = vestingStepsArray.length / 11;
    if (vestingStepsArray.length % 11 > 0) len++;
    uint256[] memory steps = new uint256[](len);
    uint256 j;
    uint256 k;
    for (uint256 i = 0; i < vestingStepsArray.length; i++) {
      if (vestingStepsArray[i].waitTime > 9999) {
        revert("waitTime cannot be more than 9999 days");
      }
      if (i > 0) {
        if (vestingStepsArray[i].percentage <= vestingStepsArray[i - 1].percentage) {
          revert("Vest percentage should be monotonic increasing");
        }
        if (vestingStepsArray[i].waitTime <= vestingStepsArray[i - 1].waitTime) {
          revert("waitTime should be monotonic increasing");
        }
      }
      steps[j] += ((vestingStepsArray[i].percentage - 1) + 100 * (vestingStepsArray[i].waitTime % (10**4))) * (10**(6 * k));
      if (i % 11 == 10) {
        j++;
        k = 0;
      } else {
        k++;
      }
    }
    if (vestingStepsArray[vestingStepsArray.length - 1].percentage != 100) {
      revert("Vest percentage should end at 100");
    }
    return (steps, "Success");
  }

  /**
   * @dev Calculate the vesting percentage, based on values in Setup.vestingSteps and extraVestingSteps[]
   * @param vestingSteps The vales of Setup.VestingSteps, first 11 events
   * @param extraVestingSteps The array of extra vesting steps
   * @param tokenListTimestamp The timestamp when token has been listed
   * @param currentTimestamp The current timestamp (it'd be, most likely, block.timestamp)

   This function is a bit tricky but it does the job very well.
   Take the example above, where the packed vesting steps are

   [
    "11010010009009008008007007006006005005004004003003002002001001000",
    "22021021020020019019018018017017016016015015014014013013012012011",
    "33032032031031030030029029028028027027026026025025024024023023022",
    "35099034033"
  ]

   The variable step is a group of 6 digits representing a VestingStep.
   The algorithm starts from the right and extract the last 6 digits to
   convert them in days and percentages. Then moves to the next 6 digits towards the left.
   When it reaches the left of the uint256, the step will be empty, i.e., equal to zero.
   Then, the parent loop proceeds with next i in the parent loop, i.e., moves
   to the next uint256 in the array.

   */
  function calculateVestedPercentage(
    uint256 vestingSteps,
    uint256[] memory extraVestingSteps,
    uint256 tokenListTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint8) {
    // must add 1 to the length to avoid that diminishing i we reach the floor and
    // the function reverts
    for (uint256 i = extraVestingSteps.length + 1; i >= 1; i--) {
      uint256 steps = i > 1 ? extraVestingSteps[i - 2] : vestingSteps;
      // the number 12 is because there are at most 11 steps
      // in any single uint256. Must add 1 to avoid a revert, like above
      for (uint256 k = 12; k >= 1; k--) {
        uint256 step = steps / (10**(6 * (k - 1)));
        if (step != 0) {
          uint256 days_ = (step / 100);
          uint256 percentage = (step % 100) + 1;
          if ((days_ * 1 days) + tokenListTimestamp <= currentTimestamp) {
            return uint8(percentage);
          }
        }
        steps %= (10**(6 * (k - 1)));
      }
    }
    return 0;
  }

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable.
  */
  function packAndHashSaleConfiguration(
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) internal pure returns (bytes32) {
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
    return
      keccak256(
        abi.encodePacked(
          "\x19\x00", /* EIP-191 */
          setup.sellingToken,
          setup.owner,
          setup.isTokenTransferable,
          setup.isFutureToken,
          setup.futureTokenSaleId,
          paymentToken,
          setup.vestingSteps,
          extraVestingSteps,
          [
            uint256(setup.pricingToken),
            uint256(setup.tokenListTimestamp),
            uint256(setup.remainingAmount),
            uint256(setup.minAmount),
            uint256(setup.capAmount),
            uint256(setup.pricingPayment),
            uint256(setup.tokenFeePoints),
            uint256(setup.totalValue),
            uint256(setup.paymentFeePoints),
            uint256(setup.extraFeePoints)
          ]
        )
      );
  }
}
