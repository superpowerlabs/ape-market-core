// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title OwnedByMultiSigOwner
 * @version 1.1.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A registry for all Ape contracts
 */

//import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IOwnedByMultiSigOwner.sol";

contract OwnedByMultiSigOwner is IOwnedByMultiSigOwner, Ownable {
  address public multiSigOwner;

  // must be set after the initial set up
  bool internal _requiresMultiSigOwner;

  modifier onlyMultiSigOwner() {
    if (_requiresMultiSigOwner) {
      require(_msgSender() != address(0) && _msgSender() == multiSigOwner, "OwnedByMultiSigOwner: not the multi sig owner");
    } else {
      require(_msgSender() == owner(), "OwnedByMultiSigOwner: not the owner");
    }
    _;
  }

  function setMultiSigOwner(address addr) external override onlyOwner {
    multiSigOwner = addr;
  }
}
