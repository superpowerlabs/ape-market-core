// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";
import "./ISATokenData.sol";
import "../sale/ISale.sol";

import "hardhat/console.sol";

contract SATokenData is ISATokenData {
  mapping(uint256 => uint256[]) internal _bundles;
  ISaleData internal _saleData;

  constructor(address saleData) {
    _saleData = ISaleData(saleData);
  }

  function _packSA(SA memory sa) internal view returns (uint256) {
    ISale sale = ISale(sa.sale);
    uint256 saleId = sale.saleId();
    return sa.vestedPercentage + saleId * 1000 + sa.remainingAmount * 100000000;
  }

  function _unpackUint256(uint256 pack) internal view returns (SA memory) {
    uint256 vestedPercentage = pack % 1000;
    uint256 saleId = ((pack - vestedPercentage) / 1000) % 100000;
    return SA(_saleData.getSaleAddressById(saleId), pack / 100000000, uint128(vestedPercentage));
  }
}
