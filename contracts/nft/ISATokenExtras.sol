// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISATokenExtras {

  function merge(uint256[] memory tokenIds) external;

  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  function beforeTokenTransfer(address from, address to, uint256 tokenId) external;

  function vest(uint256 tokenId) external returns (bool);
}
