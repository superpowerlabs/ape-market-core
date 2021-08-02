// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import "../nft/ISAStorage.sol";
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
  struct VestingStep {
    uint128 timestamp;
    uint128 percentage;
  }

  struct Setup {
    ISAToken satoken;
    IERC20Min sellingToken;
    IERC20Min paymentToken;
    address owner;
    uint256 remainingAmount;
    uint64 minAmount;
    uint64 capAmount;
    uint64 pricingToken;
    uint64 pricingPayment;
    uint64 tokenListTimestamp;
    uint64 tokenFeePercentage;
    uint64 paymentFeePercentage;
    bool isTokenTransferable;
  }

  function apeWallet() external view returns (address);

  function updateApeWallet(address apeWallet_) external;

  function nextSaleId() external view returns (uint256);

  function increaseSaleId() external;

  function isLegitSale(address sale) external view returns (bool);

  function grantManagerLevel(address saleAddress) external;

  function getSaleAddressById(uint256 saleId) external view returns (address);

  function normalize(uint256 saleId, uint64 amount) external view returns (uint256);

  function denormalize(address sellingToken, uint64 amount) external view returns (uint256);

  function setVest(
    uint256 saleId,
    uint128 lastVestedPercentage,
    uint256 lockedAmount
  ) external returns (uint128, uint256);

  function triggerTokenListing(uint256 saleId) external;

  function approveInvestor(
    uint256 saleId,
    address investor,
    uint256 amount
  ) external;

  function setWithdrawToken(uint256 saleId, uint256 amount) external returns (IERC20Min, uint256);

  function setInvest(
    uint256 saleId,
    address investor,
    uint256 amount
  )
    external
    returns (
      uint256,
      uint256,
      uint256
    );

  function setLaunch(uint256 saleId)
    external
    returns (
      IERC20Min,
      address,
      uint256
    );

  function makeTransferable(uint256 saleId) external;

  function getSetupById(uint256 saleId) external view returns (Setup memory);

  function setUpSale(
    uint256 saleId,
    address saleAddress,
    Setup memory setup,
    VestingStep[] memory schedule
  ) external;

  function getVestedPercentage(uint256 saleId) external view returns (uint128);

  function getVestedAmount(
    uint256 vestedPercentage,
    uint256 lastVestedPercentage,
    uint256 lockedAmount
  ) external view returns (uint256);
}
