// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../nft/ISANFT.sol";

interface ISale {
  function getPaymentToken() external view returns (address);

  function changeApeWallet(address apeWallet_) external;

  function apeWallet() external view returns (address);

  function saleId() external view returns (uint16);

  function launch() external;

  function extend(uint256 extraValue) external;

  function approveInvestor(address investor, uint256 amount) external;

  function invest(uint256 amount) external;

  function withdrawPayment(uint256 amount) external;

  function withdrawToken(uint256 amount) external;

  function triggerTokenListing() external;

  function makeTransferable() external;

  function isTokenListed() external view returns (bool);

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external returns (bool);
}
