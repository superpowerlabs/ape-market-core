//SPDX-License-Identifier: Unlicense
pragma solidity 0.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract Tether is ERC20 {
    constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, 1000000);
        console.log("minting 1000000");
    }


}
