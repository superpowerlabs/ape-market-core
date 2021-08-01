// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {

  event SaleApproved(uint saleId, address validator);
  event NewSale(address saleAddress);

  function updateValidator(address validator) external;

  function isLegitSale(address sale) external view returns (bool);

  function getSaleAddressById(uint256 i) external view returns (address);

  function approveSale(uint saleId, ISaleData.Setup memory setup, ISaleData.VestingStep[] memory schedule, bytes memory signature) external;

  function revokeApproval(uint saleId) external;

  function newSale(uint saleId, ISaleData.Setup memory setup, ISaleData.VestingStep[] memory schedule) external;

   function encodeForSignature(uint saleId, ISaleData.Setup memory setup, ISaleData.VestingStep[] memory schedule) external pure returns (bytes32);

}
