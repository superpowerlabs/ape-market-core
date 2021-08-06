// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ApeRegistry
 * @version 1.0.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A registry for all Ape contracts
 */

import "@openzeppelin/contracts/access/Ownable.sol";

contract ApeRegistry is Ownable {
  event RegistryUpdated(bytes32 name, address addr);

  mapping(bytes32 => address) public registry;

  function setData(bytes32[] memory names, address[] memory addrs) external onlyOwner {
    require(names.length = addrs.length, "ApeRegistry: names and addresses are inconsistent");
    for (uint256 i = 0; i < names.length; i++) {
      if (addrs[i] == address(0)) {
        delete registry[names[i]];
      } else {
        registry[names[i]] = addrs[i];
      }
      emit RegistryUpdated(name, addr);
    }
  }

}
