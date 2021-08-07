// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleFactory {
  event SaleApproved(uint256 saleId);
  event SaleRevoked(uint256 saleId);
  event NewSale(uint256 saleId, address saleAddress);

  function addValidator(address newValidator) external;

  function isValidator(address validator) external returns (bool);

  function revokeValidator(address validator) external;

  function addOperator(address newOperator) external;

  function isOperator(address operator) external view returns (bool);

  function revokeOperator(address operator) external;

  function approveSale(uint256 saleId) external;

  function revokeSale(uint256 saleId) external;

  function newSale(
    uint8 saleId,
    ISaleData.Setup memory setup,
    bytes memory validatorSignature,
    address paymentToken
  ) external;
}
