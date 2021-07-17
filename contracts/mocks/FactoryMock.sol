pragma solidity ^0.8.0;

contract FactoryMock {

  mapping (address => bool) private _sales;

  function isLegitSale(address sale) external view returns (bool) {
    return _sales[sale];
  }

  function setLegitSale(address sale) external {
    _sales[sale] = true;
  }

}
