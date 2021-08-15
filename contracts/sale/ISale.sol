// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../nft/ISANFT.sol";

interface ISale {
  function saleId() external view returns (uint16);

  function launch() external;

  function extend(uint256 extraValue) external;

  function approveInvestor(address investor, uint32 amount) external;

  function invest(uint32 amount) external;

  function withdrawPayment(uint256 amount) external;

  function withdrawToken(uint256 amount) external;

  function triggerTokenListing() external;

  function makeTransferable() external;

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external returns (bool);
}
