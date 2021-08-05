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
  // used only for input. Stored as uint256[]
  struct VestingStep {
    uint32 waitTime;
    uint8 percentage;
  }

  struct Setup {
    // 1st word:
    IERC20Min sellingToken;
    // 2nd word:
    address owner; // 160
    // pricingPayments and pricingToken builds a fraction to define the price of the token
    uint32 minAmount; // USD
    uint32 capAmount; // USD, it can be = totalValue (no cap to single investment)
    uint32 tokenListTimestamp;
    // 3rd word:
    uint120 remainingAmount; // selling token
    uint64 pricingToken;
    uint64 pricingPayment;
    uint8 tokenFeePercentage; // the fee in token paid by sellers at launch
    // 4th word, 24 more bits available:
    address saleAddress;
    uint32 totalValue; // USD
    uint8 paymentToken; //
    uint8 paymentFeePercentage; // the fee in USD paid by buyers when investing
    uint8 changeFeePercentage; // the fee in USD paid by buyers when merging, splitting...
    uint8 softCapPercentage; // if 0, no soft cap
    bool isTokenTransferable;
  }

  function getSAToken() external view returns (ISAToken);

  function apeWallet() external view returns (address);

  function updateApeWallet(address apeWallet_) external;

  function nextSaleId() external view returns (uint256);

  function increaseSaleId() external;

  function isLegitSale(address sale) external view returns (bool);

  function grantManagerLevel(address saleAddress) external;

  function getSaleAddressById(uint16 saleId) external view returns (address);

  function packVestingSteps(VestingStep[] memory schedule) external view returns (uint256[] memory);

  function calculateVestedPercentage(
    uint256[] memory steps,
    uint256 tokenListTimestamp,
    uint256 timestamp
  ) external view returns (uint256);

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

  function normalize(uint16 saleId, uint64 amount) external view returns (uint120);

  function getSetupById(uint16 saleId) external view returns (Setup memory);

  function approveInvestor(
    uint16 saleId,
    address investor,
    uint256 amount
  ) external;

  function normalizeFee(uint16 saleId, uint256 feeAmount) external returns (uint256);

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
