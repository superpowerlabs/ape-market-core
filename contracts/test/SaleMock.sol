// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../nft/SAToken.sol";

contract SaleMock {
  SAToken public token;

  function setToken(address _token) external {
    token = SAToken(_token);
  }

  function mintToken(address to, uint256 amount) external {
    token.mint(to, address(0), amount, 0);
  }
}
