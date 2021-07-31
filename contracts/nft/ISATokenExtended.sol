// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISAStorage.sol";

interface ISAToken {

  function updateFactory(address factoryAddress) external;

  function mint(address to, address sale, uint256 amount, uint128 vestedPercentage) external;

  function nextTokenId() external view returns (uint256);

  function burn(uint256 tokenId) external;

  function vest(uint256 tokenId) external returns (bool);

  function ownerOf(uint256 tokenId) external view returns (address);

  function getBundle(uint256 bundleId) external view returns (ISAStorage.Bundle memory);

//  function newBundleWithSA(uint256 bundleId, address saleAddress, uint256 remainingAmount, uint128 vestedPercentage) external;
//
//  function newEmptyBundle(uint256 bundleId) external;
//
//  function deleteBundle(uint256 bundleId) external;
//
//  function updateBundleAcquisitionTime(uint256 bundleId) external returns (bool);
//
  function increaseAmountInSA(uint256 bundleId, uint256 i, uint256 diff) external;

  function addSAToBundle(uint256 bundleId, ISAStorage.SA memory newSA) external;

}
