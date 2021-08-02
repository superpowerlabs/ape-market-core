// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../data/SATokenData.sol";

contract SATokenDataMock is SATokenData {
  constructor(address saleData) SATokenData(saleData) {}

  function packSA(SA memory sa) public view returns (uint256) {
    return _packSA(sa);
  }

  function unpackUint256(uint256 pack) public view returns (SA memory) {
    return _unpackUint256(pack);
  }
}
