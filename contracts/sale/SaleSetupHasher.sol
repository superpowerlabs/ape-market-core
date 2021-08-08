// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISaleSetupHasher.sol";

// we deploy this standalone to reduce the size of SaleFactory

contract SaleSetupHasher is ISaleSetupHasher {
  ISaleData private _saleData;

  constructor(address saleData) {
    _saleData = ISaleData(saleData);
  }

  /*
  abi.encodePacked is unable to pack structs. To get a signable hash, we need to
  put the data contained in the struct in types that are packable.
  */
  function packAndHashSaleConfiguration(
    uint256 saleId,
    ISaleData.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) public pure override returns (bytes32) {
    require(setup.remainingAmount == 0 && setup.tokenListTimestamp == 0, "SaleFactory: invalid setup");
    return
      keccak256(
        abi.encodePacked(
          "\x19\x00", /* EIP-191 */
          saleId,
          setup.sellingToken,
          setup.owner,
          setup.isTokenTransferable,
          paymentToken,
          setup.vestingSteps,
          extraVestingSteps,
          [
            uint256(setup.pricingToken),
            uint256(setup.tokenListTimestamp),
            uint256(setup.remainingAmount),
            uint256(setup.minAmount),
            uint256(setup.capAmount),
            uint256(setup.pricingPayment),
            uint256(setup.tokenFeePercentage),
            uint256(setup.totalValue),
            uint256(setup.paymentToken),
            uint256(setup.paymentFeePercentage),
            uint256(setup.softCapPercentage),
            uint256(setup.extraFeePercentage)
          ]
        )
      );
  }
}
