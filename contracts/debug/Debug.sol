// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// this contract is to test and do calculations

contract Debug {

  mapping(address => mapping(address => bool)) private _associatedAddresses;

  mapping(bytes32 => bool) private _associatedAddresses2;

  function associate(address one, address two) external {
    _associatedAddresses[one][two] = true;
    _associatedAddresses[two][one] = true;
  }

  function associate2(address one, address two) external {
    bytes32 key = keccak256(abi.encodePacked(one, two));
    _associatedAddresses2[key] = true;
  }

  function isMutualAssociatedAddress(address one, address two) external view returns (bool) {
    return (
    _associatedAddresses[one][two] &&
    _associatedAddresses[two][one]
    );
  }

  function isMutualAssociatedAddress2(address one, address two) external view returns (bool) {
    return (
    _associatedAddresses2[keccak256(abi.encodePacked(one, two))] ||
    _associatedAddresses2[keccak256(abi.encodePacked(two, one))]
    );
  }

}
