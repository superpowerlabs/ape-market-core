// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../sale/ISaleData.sol";

interface ISAToken {
  struct SA {
    uint16 saleId;
    uint120 fullAmount;
    uint120 remainingAmount;
  }

  function saleData() external view returns (ISaleData);

  function mint(
    address to,
    address sale,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external;

  function nextTokenId() external view returns (uint256);

  function burn(uint256 tokenId) external;

  function withdraw(
    uint256 tokenId,
    uint16 saleId,
    uint256 amount
  ) external;

  function areMergeable(uint256[] memory tokenIds) external view returns (bool, string memory);

  function merge(uint256[] memory tokenIds) external;

  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  function getTokenExtras() external view returns (address);

  function addSAToBundle(uint256 bundleId, SA memory newSA) external;

  function getBundle(uint256 bundleId) external view returns (SA[] memory);

  function getOwnerOf(uint256 tokenId) external view returns (address);
}
