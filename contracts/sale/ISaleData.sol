// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../nft/ISAToken.sol";

interface IERC20Min {
  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function decimals() external view returns (uint8);
}

interface ISaleData {
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

  function getSAToken() external view returns (ISAToken);

  function apeWallet() external view returns (address);

  function updateApeWallet(address apeWallet_) external;

  function updateFees(
    uint16 saleId,
    uint8 tokenFeePercentage,
    uint8 extraFeePercentage,
    uint8 paymentFeePercentage,
    uint8 changeFeePercentage
  ) external;

  function nextSaleId() external view returns (uint256);

  function increaseSaleId() external;

  function isLegitSale(address sale) external view returns (bool);

  function getSaleAddressById(uint16 saleId) external view returns (address);

  function packVestingSteps(VestingStep[] memory vestingSteps) external view returns (uint256);

  function calculateVestedPercentage(
    uint256 steps,
    uint256 tokenListTimestamp,
    uint256 currentTimestamp
  ) public view returns (uint8);

  function validateSetup(Setup memory setup) external view returns (bool, string memory);

  function validateVestingSteps(VestingStep[] memory schedule) external view returns (bool, string memory);

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    Setup memory setup,
    VestingStep[] memory schedule,
    address paymentToken
  ) external;

  function paymentTokenById(uint8 id) external view returns (address);

  function makeTransferable(uint16 saleId) external;

  function fromTotalValueToTokensAmount(uint16 saleId) external view returns (uint120);

  function setLaunch(uint16 saleId)
    external
    returns (
      IERC20Min,
      address,
      uint256
    );

  function getSetupById(uint16 saleId) external view returns (Setup memory);

  function approveInvestor(
    uint16 saleId,
    address investor,
    uint32 amount
  ) external;

  function setInvest(
    uint16 saleId,
    address investor,
    uint256 amount
  )
    external
    returns (
      uint256,
      uint256,
      uint256
    );

  function setWithdrawToken(uint16 saleId, uint256 amount) external returns (IERC20Min, uint256);

  function isVested(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external returns (bool);

  function triggerTokenListing(uint16 saleId) external;
}
