// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAToken {

  function pause(uint tokenId) external;

  function unpause(uint tokenId) external;

  function pauseBatch(uint[] memory tokenIds) external;

  function unpauseBatch(uint[] memory tokenIds) external;

  function isPaused(uint tokenId) external view returns (bool);

  function updateFactory(address factoryAddress) external;

  function updateStorage(address storageAddress) external;

  function factory() external view returns (address);

  function mint(address to, uint256 amount) external;

}
