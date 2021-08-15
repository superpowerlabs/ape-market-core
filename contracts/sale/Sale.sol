// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../nft/ISANFT.sol";
import "./ISaleData.sol";
import "./ISale.sol";
import "../registry/RegistryUser.sol";

contract Sale is ISale, RegistryUser {
  using SafeMath for uint256;

  uint16 private _saleId;

  constructor(uint16 saleId_, address registry) RegistryUser(registry) {
    _saleId = saleId_;
  }

  function saleId() external view override returns (uint16) {
    return _saleId;
  }

  function _isSaleOwner(ISaleData saleData) internal view {
    require(_msgSender() == saleData.getSetupById(_saleId).owner, "Sale: caller is not the owner");
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    (IERC20Min sellingToken, uint256 amount) = ISaleData(_get("SaleData")).setLaunchOrExtension(_saleId, 0);
    sellingToken.transferFrom(_msgSender(), address(this), amount);
  }

  // Sale creator calls this function to extend a sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function extend(uint256 extraValue) external virtual override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    (IERC20Min sellingToken, uint256 extraAmount) = ISaleData(_get("SaleData")).setLaunchOrExtension(_saleId, extraValue);
    sellingToken.transferFrom(_msgSender(), address(this), extraAmount);
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint32 amount) external virtual override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    ISaleDB.Setup memory setup = saleData.getSetupById(_saleId);
    (uint256 tokenPayment, uint256 buyerFee) = saleData.setInvest(_saleId, _msgSender(), amount);
    IERC20Min paymentToken = IERC20Min(saleData.paymentTokenById(setup.paymentTokenId));
    paymentToken.transferFrom(_msgSender(), saleData.apeWallet(), buyerFee);
    paymentToken.transferFrom(_msgSender(), address(this), tokenPayment);
  }

  function withdrawPayment(uint256 amount) external virtual override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    IERC20Min paymentToken = IERC20Min(saleData.paymentTokenById(saleData.getSetupById(_saleId).paymentTokenId));
    paymentToken.transfer(_msgSender(), amount);
  }

  function withdrawToken(uint256 amount) external virtual override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    IERC20Min sellingToken = saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(_msgSender(), amount);
  }

  function approveInvestor(address investor, uint32 amount) external override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    saleData.approveInvestor(_saleId, investor, amount);
  }

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external virtual override onlyFrom("SANFTManager") returns (bool) {
    ISaleData saleData = ISaleData(_get("SaleData"));
    if (saleData.isVested(_saleId, fullAmount, remainingAmount, requestedAmount)) {
      saleData.getSetupById(_saleId).sellingToken.transfer(saOwner, requestedAmount);
      return true;
    } else {
      return false;
    }
  }

  function makeTransferable() external override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    saleData.makeTransferable(_saleId);
  }

  function triggerTokenListing() external override {
    ISaleData saleData = ISaleData(_get("SaleData"));
    _isSaleOwner(saleData);
    saleData.triggerTokenListing(_saleId);
  }
}
