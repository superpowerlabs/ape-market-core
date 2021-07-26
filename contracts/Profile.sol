// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/Signable.sol";

contract Profile {
//
//}is Signable {
//
//  mapping(bytes32 => bool) private _associatedAddresses2;
//  uint private _validFor = 1 days;

//  function associate(address associatedAccount, uint timestamp, bytes memory signature) external {
//    require(timestamp < block.timestamp && timestamp + _validFor > block.timestamp, "Profile: request is expired");
//    require(isSignedByOracle(encodeForSignature(msg.sender, associatedAccount, timestamp), signature), "Invalid signature");
//    bytes32 key = keccak256(abi.encodePacked(one, two));
//    _associatedAddresses2[key] = true;
//  }
//
//  function areAddressesAssociated(address one, address two) external view returns (bool) {
//    return (
//    _associatedAddresses2[keccak256(abi.encodePacked(one, two))] ||
//    _associatedAddresses2[keccak256(abi.encodePacked(two, one))]
//    );
//  }
//
//  function encodeForSignature(address one, address two, uint timestamp) public pure returns (bytes32){
//    // EIP-191
//    return keccak256(abi.encodePacked(
//        "\x19\x00",
//        one,
//        two,
//        timestamp
//      ));
//  }

}
