// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract Profile is Ownable {

  event ValidityChanged(uint validity);
  event AccountsAssociated(address addr1, address addr2);
  event AccountsDissociated(address addr1, address addr2);

  mapping(bytes32 => bool) private _associatedAccounts;
  uint private _validity = 1 days;

  function changeValidity(uint validity) public onlyOwner {
    _validity = validity;
    ValidityChanged(validity);
  }

  function associateAccount(address account, uint timestamp, bytes memory signature) external {
    require(msg.sender != address(0) && account != address(0), "Profile: no invalid accounts");
    require(timestamp + _validity > block.timestamp, "Profile: request is expired");
    bytes32 hash = encodeForSignature(account, msg.sender, timestamp);
    address signer = ECDSA.recover(hash, signature);
    require(signer == account, "Profile: invalid signature");
    bytes32 key = keccak256(abi.encodePacked(msg.sender, account));
    _associatedAccounts[key] = true;
    emit AccountsAssociated(msg.sender, account);
  }

  function dissociateAccount(address associatedAccount) external {
    bool right = _associatedAccounts[keccak256(abi.encodePacked(msg.sender, associatedAccount))];
    bool left = _associatedAccounts[keccak256(abi.encodePacked(associatedAccount, msg.sender))];
    require(right || left, "Profile: association not found");
    if (right) {
      delete _associatedAccounts[keccak256(abi.encodePacked(msg.sender, associatedAccount))];
    }
    if (left) {
      delete _associatedAccounts[keccak256(abi.encodePacked(associatedAccount, msg.sender))];
    }
    emit AccountsDissociated(msg.sender, associatedAccount);
  }

  function areAccountsAssociated(address addr1, address addr2) external view returns (bool) {
    return (
    _associatedAccounts[keccak256(abi.encodePacked(addr1, addr2))] ||
    _associatedAccounts[keccak256(abi.encodePacked(addr2, addr1))]
    );
  }

  function encodeForSignature(address addr1, address addr2, uint timestamp) public pure returns (bytes32){
    return keccak256(abi.encodePacked(
        "\x19\x00", // EIP-191
        addr1, addr2, timestamp
      ));
  }

}
