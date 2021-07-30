// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import "../nft/ISAStorage.sol";
import "../nft/ISAToken.sol";


interface IERC20Min {

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

  function normalize(uint saleId, uint64 amount) external view returns (uint);

  function denormalize(address sellingToken, uint64 amount) external view returns (uint);

  function setVest(uint saleId, uint128 lastVestedPercentage, uint256 lockedAmount) external returns (uint128, uint);

  function triggerTokenListing(uint saleId) external;

  function approveInvestor(uint saleId, address investor, uint256 amount) external;

  function setWithdrawToken(uint saleId, uint256 amount) external returns (IERC20Min, uint);

  function setInvest(uint saleId, address investor, uint256 amount) external returns (uint, uint, uint);

  function setLaunch(uint saleId) external returns (IERC20Min, address, uint);

  function makeTransferable(uint saleId) external;

  function getSetupById(uint saleId) external view returns (Setup memory);

  function setUpSale(Setup memory setup, VestingStep[] memory schedule) external returns (uint);

  function grantManagerLevel(address saleAddress) external;

  function getVestedPercentage(uint saleId) external view returns (uint128);

  function getVestedAmount(uint256 vestedPercentage, uint256 lastVestedPercentage, uint256 lockedAmount) external view returns (uint256);

}
