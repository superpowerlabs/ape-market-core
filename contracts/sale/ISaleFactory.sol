// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {
  event SaleApproved(uint256 saleId);
  event SaleRevoked(uint256 saleId);
  event NewSale(uint256 saleId, address saleAddress);
  event OperatorUpdated(address operator, uint256 role);

  function getSaleIdBySetupHash(bytes32 hash) external view returns(uint16);

  // if roles is 0, the operator is removed
  function updateOperators(address operator, uint256 roles) external;

  function isOperator(address operator, uint256 roles) external view returns (bool);

  function approveSale(bytes32 setupHash) external;

  function revokeSale(bytes32 setupHash) external;

  function newSale(
    uint16 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external;
}
