// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleSetupHasher.sol";

// we deploy this standalone to reduce the size of SaleFactory

contract SaleSetupHasher is ISaleSetupHasher {

  ISaleData private _saleData;

  constructor(address saleData) {
    _saleData = ISaleData(saleData);
  }

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable.
  */

  function encodeForSignature(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    address paymentToken
  ) public view override returns (bytes32) {
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
    (uint88 firstTwoSteps, uint256[] memory steps) = _saleData.packVestingSteps(schedule);
    uint256[13] memory data = [
    uint256(setup.pricingToken),
    uint256(setup.tokenListTimestamp),
    uint256(setup.remainingAmount),
    uint256(setup.minAmount),
    uint256(setup.capAmount),
    uint256(setup.pricingPayment),
    uint256(setup.tokenFeePercentage),
    uint256(setup.totalValue),
    uint256(setup.paymentToken),
    uint256(setup.paymentFeePercentage),
    uint256(setup.changeFeePercentage),
    uint256(setup.softCapPercentage),
    uint256(setup.extraFeePercentage)
    ];
    return
    keccak256(
      abi.encodePacked(
        "\x19\x00", /* EIP-191 */
        saleId,
        setup.sellingToken,
        setup.owner,
        firstTwoSteps,
        steps,
        data,
        setup.isTokenTransferable,
        paymentToken
      )
    );
  }
}
