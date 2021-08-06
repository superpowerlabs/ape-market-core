// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

import "../nft/ISAToken.sol";
import "./ISaleData.sol";

contract Sale {
  using SafeMath for uint256;

  ISaleData private _saleData;

  uint16 private _saleId;

  modifier onlySaleOwner() {
    require(msg.sender == _saleData.getSetupById(_saleId).owner, "Sale: caller is not the owner");
    _;
  }

  constructor(uint16 saleId_, address saleData) {
    _saleId = saleId_;
    _saleData = ISaleData(saleData);
  }

  function saleId() external view returns (uint16) {
    return _saleId;
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
    IERC20Min paymentToken = IERC20Min(_saleData.paymentTokenById(setup.paymentToken));
    paymentToken.transferFrom(msg.sender, _saleData.apeWallet(), buyerFee);
    paymentToken.transferFrom(msg.sender, address(this), tokenPayment);
    // mint NFT
    ISAToken nft = _saleData.getSAToken();
    nft.mint(msg.sender, address(0), uint120(amount), uint120(amount));
    nft.mint(_saleData.apeWallet(), address(0), uint120(sellerFee), uint120(sellerFee));
  }

  function payFee(address payer, uint120 feeAmount) external {
    require(msg.sender == _saleData.getSAToken().getTokenExtras(), "Sale: only SATokenExtras can call this function");
    if (feeAmount > 0) {
      IERC20Min paymentToken = IERC20Min(_saleData.paymentTokenById(_saleData.getSetupById(_saleId).paymentToken));
      paymentToken.transferFrom(payer, _saleData.apeWallet(), feeAmount);
    }
  }

  function withdrawPayment(uint256 amount) external virtual onlySaleOwner {
    IERC20Min paymentToken = IERC20Min(_saleData.paymentTokenById(_saleData.getSetupById(_saleId).paymentToken));
    paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual onlySaleOwner {
    (IERC20Min sellingToken, uint256 fee) = _saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(msg.sender, amount + fee);
  }

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external virtual returns (bool) {
    require(msg.sender == _saleData.getSAToken().getTokenExtras(), "Sale: only SATokenExtras can call vest");
    if (_saleData.isVested(_saleId, fullAmount, remainingAmount, requestedAmount)) {
      _saleData.getSetupById(_saleId).sellingToken.transfer(saOwner, requestedAmount);
      return true;
    } else {
      return false;
    }
  }
}
