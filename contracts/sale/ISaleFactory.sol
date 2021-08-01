// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {
  event SaleApproved(uint256 saleId, address validator);
  event NewSale(address saleAddress);

  function updateValidator(address validator) external;

  function isLegitSale(address sale) external view returns (bool);

  function getSaleAddressById(uint256 i) external view returns (address);

  function approveSale(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule,
    bytes memory signature
  ) external;

  function revokeApproval(uint256 saleId) external;

  function newSale(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule
  ) external;

  function encodeForSignature(
    uint256 saleId,
    ISaleData.Setup memory setup,
    ISaleData.VestingStep[] memory schedule
  ) external pure returns (bytes32);
}
