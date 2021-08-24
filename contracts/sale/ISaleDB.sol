// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Min {
  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function decimals() external view returns (uint8);
}

interface ISaleDB {
  // VestingStep is used only for input.
  // The actual schedule is stored as a single uint256
  struct VestingStep {
    uint256 waitTime;
    uint256 percentage;
  }

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
    uint8 paymentTokenId; // << TokenRegistry Id of the token used for the payments (USDT, USDC...)
    //
    uint256 vestingSteps; // < at most 15 vesting events
    //
    IERC20Min sellingToken;
    // 96 more bits available here
    //
    address saleAddress; // 160
    uint32 totalValue; // << USD
    bool isTokenTransferable;
    uint16 tokenFeePoints; // << the fee in sellingToken due by sellers at launch
    // a value like 3.25% is set as 325 base points
    uint16 extraFeePoints; // << the optional fee in USD paid by seller at launch
    uint16 paymentFeePoints; // << the fee in USD paid by buyers when investing
    //  more bits available:
  }

  function nextSaleId() external view returns (uint256);

  function increaseSaleId() external;

  function getSaleIdByAddress(address saleAddress) external view returns (uint16);

  function getSaleAddressById(uint16 saleId) external view returns (address);

  function initSale(
    uint16 saleId,
    Setup memory setup,
    uint256[] memory extraVestingSteps
  ) external;

  function triggerTokenListing(uint16 saleId) external;

  function updateRemainingAmount(
    uint16 saleId,
    uint120 remainingAmount,
    bool increment
  ) external;

  function makeTransferable(uint16 saleId) external;

  function getSetupById(uint16 saleId) external view returns (Setup memory);

  function getExtraVestingStepsById(uint16 saleId) external view returns (uint256[] memory);

  function setApproval(
    uint16 saleId,
    address investor,
    uint32 amount
  ) external;

  function deleteApproval(uint16 saleId, address investor) external;

  function getApproval(uint16 saleId, address investor) external returns (uint256);
}
