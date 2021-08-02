// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../data/SaleData.sol";

contract SaleDataMock is SaleData {
  constructor(address wallet) SaleData(wallet) {}

  mapping(uint256 => address) private _salesById;

  function saveSaleById(uint256 saleId, address sale) public {
    _salesById[saleId] = sale;
  }
}
