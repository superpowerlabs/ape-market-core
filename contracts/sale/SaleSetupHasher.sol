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
    uint256 len = vestingStepsArray.length / 15;
    uint256[] memory errorCode = new uint256[](1);
    if (vestingStepsArray.length % 15 > 0) len++;
    uint256[] memory steps = new uint256[](len);
    uint256 j;
    uint256 k;
    for (uint256 i = 0; i < vestingStepsArray.length; i++) {
      if (vestingStepsArray[i].waitTime > 999) {
        errorCode[0] = 4;
        return (errorCode, "waitTime cannot be more than 999 days");
      }
      if (i > 0) {
        if (vestingStepsArray[i].percentage <= vestingStepsArray[i - 1].percentage) {
          errorCode[0] = 1;
          return (errorCode, "Vest percentage should be monotonic increasing");
        }
        if (vestingStepsArray[i].waitTime <= vestingStepsArray[i - 1].waitTime) {
          errorCode[0] = 2;
          return (errorCode, "waitTime should be monotonic increasing");
        }
      }
      steps[j] += ((vestingStepsArray[i].percentage - 1) + 100 * (vestingStepsArray[i].waitTime % (10**3))) * (10**(5 * k));
      if (i % 15 == 14) {
        j++;
        k = 0;
      } else {
        k++;
      }
    }
    if (vestingStepsArray[vestingStepsArray.length - 1].percentage != 100) {
      errorCode[0] = 3;
      return (errorCode, "Vest percentage should end at 100");
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
