// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {
  event SaleApproved(uint256 saleId);
  event SaleRevoked(uint256 saleId);
  event NewSale(uint256 saleId, address saleAddress);
  event OperatorUpdated(address operator, uint256 role);

  // if roles is 0, the operator is removed
  function updateOperators(address operator, uint256 roles) external;

  function isOperator(address operator, uint256 roles) external view returns (bool);

  function approveSale(uint16 saleId, bytes32 setupHash) external;

  function revokeSale(uint16 saleId) external;

  function newSale(
    uint16 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken,
    bytes memory validatorSignature
  ) external;
}
