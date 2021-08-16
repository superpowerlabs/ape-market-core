// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../nft/ISANFT.sol";
import "./ISaleData.sol";
import "../registry/RegistryUser.sol";

contract Sale is RegistryUser {
  using SafeMath for uint256;

  uint16 private _saleId;

  modifier onlySaleOwner() {
    require(_msgSender() == ISaleData(_get("SaleData")).getSetupById(_saleId).owner, "Sale: caller is not the owner");
    _;
  }

  constructor(uint16 saleId_, address registry) RegistryUser(registry) {
    _saleId = saleId_;
  }

  function saleId() external view returns (uint16) {
    return _saleId;
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual onlySaleOwner {
    (IERC20Min sellingToken, address owner, uint256 amount) = ISaleData(_get("SaleData")).setLaunch(_saleId);
    sellingToken.transferFrom(owner, address(this), amount);
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint32 amount) external virtual {
    ISaleData saleData = ISaleData(_get("SaleData"));
    ISaleDB.Setup memory setup = saleData.getSetupById(_saleId);
    (uint256 tokenPayment, uint256 buyerFee) = saleData.setInvest(_saleId, _msgSender(), amount);
    IERC20Min paymentToken = IERC20Min(saleData.paymentTokenById(setup.paymentTokenId));
    paymentToken.transferFrom(_msgSender(), saleData.apeWallet(), buyerFee);
    paymentToken.transferFrom(_msgSender(), address(this), tokenPayment);
  }

  function withdrawPayment(uint256 amount) external virtual onlySaleOwner {
    ISaleData saleData = ISaleData(_get("SaleData"));
    IERC20Min paymentToken = IERC20Min(saleData.paymentTokenById(saleData.getSetupById(_saleId).paymentTokenId));
    paymentToken.transfer(_msgSender(), amount);
  }

  function withdrawToken(uint256 amount) external virtual onlySaleOwner {
    ISaleData saleData = ISaleData(_get("SaleData"));
    (IERC20Min sellingToken, uint256 fee) = saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(_msgSender(), amount + fee);
  }

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external virtual onlyFrom("SANFTManager") returns (bool) {
    ISaleData saleData = ISaleData(_get("SaleData"));
    if (saleData.isVested(_saleId, fullAmount, remainingAmount, requestedAmount)) {
      saleData.getSetupById(_saleId).sellingToken.transfer(saOwner, requestedAmount);
      return true;
    } else {
      return false;
    }
  }

  function updateRegisteredContracts() external virtual override {}
}
