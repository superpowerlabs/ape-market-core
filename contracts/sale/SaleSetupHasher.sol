// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleSetupHasher.sol";
import "../registry/FakeRegistryUser.sol";

// we deploy this standalone to reduce the size of SaleFactory

contract SaleSetupHasher is ISaleSetupHasher, FakeRegistryUser {
  /**
   * @dev Validate and pack a VestingStep[]. It must be called by the dApp during the configuration of the Sale setup. The same code can be executed in Javascript, but running a function on a smart contract guarantees future compatibility.
   * @param vestingStepsArray The array of VestingStep
   */

  function validateAndPackVestingSteps(ISaleDB.VestingStep[] memory vestingStepsArray)
    external
    pure
    override
    returns (uint256[] memory, string memory)
  {
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

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable.
  */
  function packAndHashSaleConfiguration(
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) public pure override returns (bytes32) {
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
