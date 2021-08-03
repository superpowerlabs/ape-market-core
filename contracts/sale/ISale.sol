// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../data/ISATokenData.sol";

interface ISale {
  function getPaymentToken() external view returns (address);

  function changeApeWallet(address apeWallet_) external;

  function apeWallet() external view returns (address);

  function saleId() external view returns (uint256);

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external;

  // Sale creator calls this function to approve investor.
  // can be called repeated. unused amount can be forfeited by setting it to 0
  function approveInvestor(address investor, uint256 amount) external;

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external;

  function normalize(uint32 amount) external view returns (uint256);

  function payFee(address payer, uint256 feeAmount) external;

  function withdrawPayment(uint256 amount) external;

  function withdrawToken(uint256 amount) external;

  function triggerTokenListing() external;

  function makeTransferable() external;

  function isTransferable() external view returns (bool);

  function isTokenListed() external view returns (bool);

  function vest(address saOwner, ISATokenData.SA memory sa) external returns (uint128, uint256);
}
