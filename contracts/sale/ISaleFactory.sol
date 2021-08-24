// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {
  event SaleApproved(uint256 saleId);
  event SaleRevoked(uint256 saleId);
  event NewSale(uint256 saleId, address saleAddress);
  event OperatorAdded(address operator, uint role);

  function addOperator(address newOperator, uint roles) external;

  function isOperator(address operator, uint roles) external view returns (bool);

  function revokeOperator(address operator) external;

  function approveSale(uint256 saleId) external;

  function revokeSale(uint256 saleId) external;

  function newSale(
    uint8 saleId,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken,
    bytes memory validatorSignature
  ) external;
}
