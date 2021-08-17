// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IFakeRegistryUser.sol";

contract FakeRegistryUser is IFakeRegistryUser {
  function updateRegisteredContracts() external override {}
}
