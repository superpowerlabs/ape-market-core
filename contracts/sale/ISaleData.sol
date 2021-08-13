// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../nft/ISANFT.sol";
import "./ISaleDB.sol";

interface ISaleData {
  event ApeWalletUpdated(address wallet);
  event SaleSetup(uint16 saleId, address saleAddress);
  event SaleLaunched(uint16 saleId, uint32 totalValue, uint120 totalTokens);
  event SaleExtended(uint16 saleId, uint32 extraValue, uint120 extraTokens);
  event TokenListed(uint16 saleId);

  function apeWallet() external view returns (address);

  function updateApeWallet(address apeWallet_) external;

  function increaseSaleId() external;

  function calculateVestedPercentage(
    uint256 vestingSteps,
    uint256[] memory extraVestingSteps,
    uint256 tokenListTimestamp,
    uint256 currentTimestamp
  ) external pure returns (uint8);

  function vestedPercentage(uint16 saleId) external view returns (uint8);

  function validateAndPackVestingSteps(ISaleDB.VestingStep[] memory vestingStepsArray)
    external
    pure
    returns (uint256[] memory, string memory);

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external;

  function getTokensAmountAndFeeByValue(uint16 saleId, uint32 value) external view returns (uint, uint);
  function paymentTokenById(uint8 id) external view returns (address);

  function makeTransferable(uint16 saleId) external;

  function fromValueToTokensAmount(uint16 saleId, uint32 value) external view returns (uint);

  function fromTokensAmountToValue(uint16 saleId, uint120 amount) external view returns (uint32);

  function setLaunchOrExtension(uint16 saleId, uint value)
  external
  returns (
    IERC20Min,
    uint256
  );

  function getSetupById(uint16 saleId) external view returns (ISaleDB.Setup memory);

  function approveInvestor(
    uint16 saleId,
    address investor,
    uint32 amount
  ) external;

  function setInvest(
    uint16 saleId,
    address investor,
    uint256 amount
  ) external returns (uint256, uint256);

  function setWithdrawToken(uint16 saleId, uint256 amount) external returns (IERC20Min, uint256);

  function isVested(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external view returns (bool);

  function vestedAmount(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external view returns (uint256);

  function triggerTokenListing(uint16 saleId) external;
}
