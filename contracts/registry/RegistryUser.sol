// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ApeRegistry
 * @version 1.0.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A registry for all Ape contracts
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IApeRegistry.sol";

contract RegistryUser is Ownable {
  IApeRegistry internal _registry;
  address internal _owner;

  modifier onlyFrom(string memory contractName) {
    require(msg.sender == _get(contractName), "IApeRegistry: forbidden");
    _;
  }

  constructor(address addr) {
    _registry = IApeRegistry(addr);
  }

  function _get(string memory contractName) internal view returns (address) {
    return _registry.get(keccak256(abi.encodePacked(contractName)));
  }

  function _update(address addr) external onlyOwner {
    _registry = IApeRegistry(addr);
  }
}
