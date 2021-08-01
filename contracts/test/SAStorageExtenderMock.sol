// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../nft/SAStorage.sol";

contract SAStorageExtenderMock is SAStorage {
  function newBundleWithSA(
    uint256 tokenId,
    address saleAddress,
    uint256 remainingAmount,
    uint128 vestedPercentage
  ) external virtual onlyLevel(MANAGER_LEVEL) {
    _newEmptyBundle(tokenId);
    SA memory listedSale = SA(saleAddress, remainingAmount, vestedPercentage);
    _addSAToBundle(tokenId, listedSale);
  }

  function newEmptyBundle(uint256 tokenId) external virtual onlyLevel(MANAGER_LEVEL) {
    _newEmptyBundle(tokenId);
  }

  function deleteBundle(uint256 tokenId) external virtual onlyLevel(MANAGER_LEVEL) {
    _deleteBundle(tokenId);
  }
}
