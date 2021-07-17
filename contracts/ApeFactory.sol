// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Sale2.sol";
//import "./Ape.sol";

// for debugging only
//import "hardhat/console.sol";

contract ApeFactory is Ownable {

  event NewSale(address saleAddress);

  mapping (address => bool) private _sales;

  function isLegitSale(address sale) external view returns (bool) {
    return _sales[sale];
  }

  function newSale(
    Sale2.Setup memory setup,
    Sale2.VestingStep[] memory schedule
  ) external
  onlyOwner
  returns(address saleAddress) {

    bytes memory bytecode = type(Sale2).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(_msgSender(), owner(), address(0)));      // Project owner, Factory Owner
    assembly {
      saleAddress := create2(0, add(bytecode, 48), mload(bytecode), salt)
    }

    Sale2(saleAddress).setup(setup, schedule);

    _sales[saleAddress] = true;
    emit NewSale(address(addresses_[0]));
    return saleAddress;
  }
}
