// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../sale/ISaleData.sol";

interface ISANFT {
  // Hold the data of a Smart Agreement, packed into an uint256
  struct SA {
    uint16 saleId; // the sale that generated this SA
    uint120 fullAmount; // the initial amount without any vesting
    // the amount remaining in the SA that's not withdrawn.
    // some of the remainingAmount can be vested already.
    uint120 remainingAmount;
  }

  function mint(
    address recipient,
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external;

  function mint(address recipient, SA[] memory bundle) external;

  function nextTokenId() external view returns (uint256);

  function burn(uint256 tokenId) external;

  function withdraw(uint256 tokenId, uint256[] memory amounts) external;

  function withdrawables(uint256 tokenId) external view returns (uint16[] memory, uint256[] memory);

  function addSAToBundle(uint256 bundleId, SA memory newSA) external;

  function getBundle(uint256 bundleId) external view returns (SA[] memory);

  function getOwnerOf(uint256 tokenId) external view returns (address);
}
