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
   struct Setup {
    //
    address owner;
    uint32 minAmount; // << USD
    uint32 capAmount; // << USD, it can be = totalValue (no cap to single investment)
    uint32 tokenListTimestamp;
    //
    uint120 remainingAmount; // << selling token
    // pricingPayments and pricingToken builds a fraction to define the price of the token
    uint64 pricingToken;
    uint64 pricingPayment;
    uint8 paymentToken; // << TokenRegistry Id of the token used for the payments (USDT, USDC...)
    //
    uint256 vestingSteps; // < at most 15 vesting events
    //
    IERC20Min sellingToken;
    // 96 more bits available here
    //
    address saleAddress;
    uint32 totalValue; // << USD
    bool isTokenTransferable;
    uint8 tokenFeePercentage; // << the fee in sellingToken due by sellers at launch
    uint8 extraFeePercentage; // << the optional fee in USD paid by seller at launch
    uint8 paymentFeePercentage; // << the fee in USD paid by buyers when investing
    uint8 changeFeePercentage; // << the fee in sellingToken due when merging, splitting...
    uint8 softCapPercentage; // << if 0, no soft cap - not sure we will implement it
    // 24 more bits available:
  }
*/

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable.
  */
  function encodeForSignature(
    uint256 saleId,
    ISaleData.Setup memory setup,
    address paymentToken
  ) public view override returns (bytes32) {
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
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
          setup.vestingSteps,
          data,
          setup.isTokenTransferable,
          paymentToken
        )
      );
  }
}
