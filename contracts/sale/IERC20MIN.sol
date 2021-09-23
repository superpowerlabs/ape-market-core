// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Min {
  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function decimals() external view returns (uint8);

  function balanceOf(address account) external view returns (uint256);
}