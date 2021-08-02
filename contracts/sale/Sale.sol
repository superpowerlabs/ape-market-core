// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

import "../data/ISATokenData.sol";
import "../data/ISaleData.sol";

contract Sale {
  using SafeMath for uint256;

  ISaleData private _saleData;

  uint256 private _saleId;

  modifier onlySaleOwner() {
    require(msg.sender == _saleData.getSetupById(_saleId).owner, "Sale: caller is not the owner");
    _;
  }

  constructor(uint256 saleId_, address saleData) {
    _saleId = saleId_;
    _saleData = ISaleData(saleData);
  }

  function saleId() external view returns (uint256) {
    return _saleId;
  }

  function initialize(ISaleData.Setup memory setup_, ISaleData.VestingStep[] memory schedule) external {
    _saleData.setUpSale(_saleId, address(this), setup_, schedule);
  }

  function isTransferable() external view returns (bool) {
    return _saleData.getSetupById(_saleId).isTokenTransferable;
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual onlySaleOwner {
    (IERC20Min sellingToken, address owner, uint256 amount) = _saleData.setLaunch(_saleId);
    sellingToken.transferFrom(owner, address(this), amount);
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external virtual {
    ISaleData.Setup memory setup = _saleData.getSetupById(_saleId);
    (uint256 tokenPayment, uint256 buyerFee, uint256 sellerFee) = _saleData.setInvest(_saleId, msg.sender, amount);
//        console.log("tokenPayment", tokenPayment);
    setup.paymentToken.transferFrom(msg.sender, _saleData.apeWallet(), buyerFee);
    setup.paymentToken.transferFrom(msg.sender, address(this), tokenPayment);
    // mint NFT
    ISAToken nft = ISAToken(setup.satoken);
    nft.mint(msg.sender, address(0), amount, 0);
    nft.mint(_saleData.apeWallet(), address(0), sellerFee, 0);
    //    console.log("Sale: Paying buyer fee", buyerFee);
    //    console.log("Sale: Paying seller fee", sellerFee);
  }

  function withdrawPayment(uint256 amount) external virtual onlySaleOwner {
    _saleData.getSetupById(_saleId).paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual onlySaleOwner {
    (IERC20Min sellingToken, uint256 fee) = _saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(msg.sender, amount + fee);
  }

  function vest(address saOwner, ISATokenData.SA memory sa) external virtual returns (uint128, uint256) {
    ISaleData.Setup memory setup = _saleData.getSetupById(_saleId);
    ISAToken token = ISAToken(setup.satoken);
    require(msg.sender == token.getTokenExtras(), "Sale: only SATokenExtras can call vest");
    (uint128 vestedPercentage, uint256 vestedAmount) = _saleData.setVest(
      _saleId,
      sa.vestedPercentage,
      sa.remainingAmount
    );
//    console.log( vestedPercentage, vestedAmount);
    // console.log("gas left before transfer", gasleft());
    if (vestedAmount > 0) {
      setup.sellingToken.transfer(saOwner, vestedAmount);
    }
    // console.log("gas left after transfer", gasleft());
    return (vestedPercentage, vestedAmount);
  }
}
