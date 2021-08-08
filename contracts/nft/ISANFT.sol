// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../sale/ISaleData.sol";

interface ISANFT {
  struct SA {
    uint16 saleId;
    uint120 fullAmount;
    uint120 remainingAmount;
  }

  function mint(
    address to,
    address saleAddress,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external;

  function nextTokenId() external view returns (uint256);

  function burn(uint256 tokenId) external;

  function withdraw(uint256 tokenId, uint256[] memory amounts) external;

  function addSAToBundle(uint256 bundleId, SA memory newSA) external;

  function getBundle(uint256 bundleId) external view returns (SA[] memory);

  function getOwnerOf(uint256 tokenId) external view returns (address);
}
