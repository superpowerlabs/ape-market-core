// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {
  event SaleApproved(uint256 saleId);
  event SaleRevoked(uint256 saleId);
  event NewSale(uint256 saleId, address saleAddress);
  event OperatorUpdated(address operator, bool isOperator);

  function getSaleIdBySetupHash(bytes32 hash) external view returns (uint16);

  function setOperator(address operator, bool isOperator_) external;

  function isOperator(address operator) external view returns (bool);

  function approveSale(bytes32 setupHash) external;

  function isSaleApproved(bytes32 setupHash, uint16 saleId) external view returns (bool);

  function revokeSale(bytes32 setupHash) external;

  function newSale(
    uint16 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external;
}
