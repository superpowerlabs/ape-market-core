// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISANFTManager {
  function updatePayments(address apeWallet_, uint256 feePoints_) external;

  function mintInitialTokens(
    address investor,
    address saleAddress,
    uint256 amount,
    uint256 sellerFee
  ) external;

  function areMergeable(uint256[] memory tokenIds)
    external
    view
    returns (
      bool,
      string memory,
      uint256
    );

  function merge(uint256[] memory tokenIds) external;

  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  function beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function withdraw(uint256 tokenId, uint256[] memory amounts) external;

  function withdrawables(uint256 tokenId) external view returns (uint16[] memory, uint256[] memory);
}
