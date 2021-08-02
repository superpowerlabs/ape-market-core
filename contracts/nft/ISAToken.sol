// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAToken {
  function mint(
    address to,
    address sale,
    uint256 amount,
    uint128 vestedPercentage
  ) external;

  function nextTokenId() external view returns (uint256);

  function burn(uint256 tokenId) external;

  function vest(uint256 tokenId) external returns (bool);

  function merge(uint256[] memory tokenIds) external;

  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  function getTokenExtras() external view returns (address);
}
