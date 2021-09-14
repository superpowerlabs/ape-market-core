// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/token/ERC20/ERC20.sol";
contract Ape is ERC20 {
  constructor(string memory tokenName, string memory tokenSymbol, address receiver) ERC20(tokenName, tokenSymbol) {
    _mint(receiver, 10 ** 27);  // 1B token, with default 18 decimals
  }
}

