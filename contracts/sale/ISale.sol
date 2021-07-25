// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../nft/ISAStorage.sol";
import "../nft/ISAToken.sol";


interface ERC20Min {

//  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

//  function allowance(address owner, address spender) external view returns (uint256);

//  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function decimals() external view returns (uint8);

}

interface ISale {


  // One step in the vesting schedule
  struct VestingStep {
    uint256 timestamp; // how many seconds needs to pass after the token is listed.
    // how much percentage of token should be vested/unlocked at current step.
    // note it is accumulative, the last step should equal to 100%
    uint256 percentage;
  }

  // This struct contains the basic information about the sale.
  struct Setup {
    ISAToken satoken; // The deployed address of SANFT contract
    ERC20Min sellingToken; // the contract address of the token being offered in this sale
    ERC20Min paymentToken;
    // owner is the one that creates the sale, receives the payments and
    // pays out tokens.  also the operator.  could be split into multiple
    // roles.  using one for simplification.
    address owner;
    uint256 remainingAmount; // how much token are still up for sale
    uint32 minAmount; // minimum about of token needs to be purchased for each invest transaction
    uint32 capAmount; // the max number, for recording purpose. not changed by contract
    // since selling token can be very expensive or very cheap in relation to the payment token
    // and solidity does not have fraction, we use pricing pair to denote the pricing
    // at straight integer lever, disregarding decimals.
    // e.g if pricingToken = 2 and pricingPayment = 5, means 2 token is worth 5 payment at
    // solidity integer level.
    uint32 pricingToken;
    uint32 pricingPayment;
    // != 0 means the token has been listed at this timestamp, it will
    // be used as the base for vesting schedule
    uint32 tokenListTimestamp;
    uint32 tokenFeePercentage;
    uint32 paymentFeePercentage;
    bool isTokenTransferable;
  }

  function getPaymentToken() external view returns (address);

  function changeApeWallet(address apeWallet_) external;

  function apeWallet() external view returns (address);

// Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external;

  // Sale creator calls this function to approve investor.
  // can be called repeated. unused amount can be forfeited by setting it to 0
  function approveInvestor(address investor, uint256 amount) external;

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external;

  function withdrawPayment(uint256 amount) external;

  function withdrawToken(uint256 amount) external;

  function triggerTokenListing() external;

  function makeTransferable() external;

  function isTransferable() external view returns(bool);

  function isTokenListed() external view returns (bool);

  function getVestedPercentage() external view returns (uint256);

  function getVestedAmount(uint256 vestedPercentage, uint256 lastVestedPercentage, uint256 lockedAmount) external view returns (uint256);

  function vest(address sa_owner, ISAStorage.SA memory sa) external returns (uint, uint);
}
