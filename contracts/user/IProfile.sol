// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProfile {

  event ValidityChanged(uint validity);
  event AccountsAssociated(address addr1, address addr2);
  event AccountsDissociated(address addr1, address addr2);

  function changeValidity(uint validity) external;

  function associateAccount(address account, uint timestamp, bytes memory signature) external;

  function dissociateAccount(address account) external;

  function areAccountsAssociated(address addr1, address addr2) external view returns (bool);

  function isMyAssociated(address addr) external view returns (bool);

  function encodeForSignature(address addr1, address addr2, uint timestamp) external view returns (bytes32);

}
