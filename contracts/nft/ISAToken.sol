// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISAToken {

  function updateFactory(address factoryAddress) external;

  function updateStorage(address storageAddress) external;

  function factory() external view returns (address);

  //  function mint(address to, uint256 amount) external;

  function mint(address to, address sale, uint256 amount, uint128 vestedPercentage) external;

  //  function mintWithExistingBundle(address to) external;

  function nextTokenId() external view returns (uint);

  function burn(uint256 tokenId) external;

  function vest(uint256 tokenId) external returns (bool);

}
