// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

import "./IProfile.sol";

contract Profile is IProfile, Ownable {

  mapping(address => bool) private _associatedAccounts;
  uint256 private _validity = 1 days;

  function changeValidity(uint256 validity) external override onlyOwner {
    _validity = validity;
    ValidityChanged(validity);
  }

  function _getPseudoAddress(address addr1, address addr2) private pure returns (address){
    return address(uint160(uint256(uint160(addr1)) + uint256(uint160(addr2))));
  }

  function associateAccount(address account, uint256 timestamp, bytes memory signature) external override {
    require(msg.sender != address(0) && account != address(0), "Profile: no invalid accounts");
    require(timestamp + _validity > block.timestamp, "Profile: request is expired");
    require(ECDSA.recover(encodeForSignature(account, msg.sender, timestamp), signature) == account, "Profile: invalid signature");
    _associatedAccounts[_getPseudoAddress(msg.sender, account)] = true;
    emit AccountsAssociated(msg.sender, account);
  }

  function dissociateAccount(address account) external override {
    require(areAccountsAssociated(msg.sender, account), "Profile: association not found");
    delete _associatedAccounts[_getPseudoAddress(msg.sender, account)];
    emit AccountsDissociated(msg.sender, account);
  }

  function areAccountsAssociated(address addr1, address addr2) public view override returns (bool) {
    return _associatedAccounts[_getPseudoAddress(addr1, addr2)];
  }

  function isMyAssociated(address addr) external view override returns (bool) {
    return areAccountsAssociated(msg.sender, addr);
  }

  function encodeForSignature(address addr1, address addr2, uint256 timestamp) public pure override returns (bytes32){
    return keccak256(abi.encodePacked("\x19\x00"/* EIP-191 */, addr1, addr2, timestamp));
  }

}
