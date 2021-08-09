// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TetherMock is ERC20 {
  constructor() ERC20("Tether", "USDT") {
    _mint(msg.sender, 10**32);
  }

  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}
