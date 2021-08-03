// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISATokenExtras {
  function areMergeable(address owner, uint256[] memory tokenIds) external view returns (string memory);

  function merge(address owner, uint256[] memory tokenIds) external;

  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  function beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function vest(uint256 tokenId) external returns (bool);

  function isContract(address account) external view returns (bool);
}
