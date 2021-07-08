pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Ape is ERC20 {
  uint256 private _tokenPrice;
  constructor() ERC20("APE Token", "APE") {
    // TODO: change to correct supply
    _mint(msg.sender, 10000);
    _tokenPrice = 1;
  }

  function currentTokenPrice() external virtual view returns (uint256) {
    // fall back: use selling price
    return _tokenPrice;
  }

  function setTokenPrice(uint price) external virtual {
    _tokenPrice = price;
  }
}
