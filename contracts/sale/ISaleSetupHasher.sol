// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleData.sol";

interface ISaleSetupHasher {
  function packAndHashSaleConfiguration(
    uint256 saleId,
    ISaleData.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external pure returns (bytes32);
}
