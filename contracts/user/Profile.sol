// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

import "./IProfile.sol";

contract Profile is IProfile, Ownable {

  mapping(bytes32 => bool) private _associatedAccounts;
  uint private _validity = 1 days;

  function changeValidity(uint validity) external override onlyOwner {
    _validity = validity;
    ValidityChanged(validity);
  }

  function _packAddresses(address addr1, address addr2) private pure returns (bytes32){
    uint o = uint256(uint160(addr1));
    uint t = uint256(uint160(addr2));
    return keccak256(abi.encodePacked(o + t));
  }

  function associateAccount(address account, uint timestamp, bytes memory signature) external override {
    require(msg.sender != address(0) && account != address(0), "Profile: no invalid accounts");
    require(timestamp + _validity > block.timestamp, "Profile: request is expired");
    bytes32 hash = encodeForSignature(account, msg.sender, timestamp);
    address signer = ECDSA.recover(hash, signature);
    require(signer == account, "Profile: invalid signature");
    _associatedAccounts[_packAddresses(msg.sender, account)] = true;
    emit AccountsAssociated(msg.sender, account);
  }

  function dissociateAccount(address account) external override {
    require(areAccountsAssociated(msg.sender, account), "Profile: association not found");
    delete _associatedAccounts[_packAddresses(msg.sender, account)];
    emit AccountsDissociated(msg.sender, account);
  }

  function areAccountsAssociated(address addr1, address addr2) public view override returns (bool) {
    return _associatedAccounts[_packAddresses(addr1, addr2)];
  }

  function isMyAssociated(address addr) external view override returns (bool) {
    return areAccountsAssociated(msg.sender, addr);
  }

  function encodeForSignature(address addr1, address addr2, uint timestamp) public pure override returns (bytes32){
    return keccak256(abi.encodePacked(
        "\x19\x00", // EIP-191
        addr1, addr2, timestamp
      ));
  }

}
