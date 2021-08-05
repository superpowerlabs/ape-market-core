// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISATokenExtras {
  function areMergeable(address owner, uint256[] memory tokenIds)
    external
    view
    returns (
      bool,
      string memory,
      uint256 count
    );

  function merge(address owner, uint256[] memory tokenIds) external;

  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  function beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function withdraw(
    uint256 tokenId,
    uint16 saleId,
    uint256 amount
  ) external;

  function isContract(address account) external view returns (bool);
}
