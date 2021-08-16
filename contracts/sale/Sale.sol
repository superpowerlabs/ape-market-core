// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../nft/ISANFT.sol";
import "./ISaleData.sol";
import "../registry/RegistryUser.sol";

contract Sale is RegistryUser {
  using SafeMath for uint256;

  uint16 private _saleId;
  ISaleData _saleData;

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

    ISaleDB.Setup memory setup = _saleData.getSetupById(_saleId);
    (uint256 tokenPayment, uint256 buyerFee) = _saleData.setInvest(_saleId, _msgSender(), amount);
    IERC20Min paymentToken = IERC20Min(_saleData.paymentTokenById(setup.paymentTokenId));
    paymentToken.transferFrom(_msgSender(), _saleData.apeWallet(), buyerFee);
    paymentToken.transferFrom(_msgSender(), address(this), tokenPayment);
  }

  function withdrawPayment(uint256 amount) external virtual onlySaleOwner {
    IERC20Min paymentToken = IERC20Min(_saleData.paymentTokenById(_saleData.getSetupById(_saleId).paymentTokenId));
    paymentToken.transfer(_msgSender(), amount);
  }

  function withdrawToken(uint256 amount) external virtual onlySaleOwner {
    (IERC20Min sellingToken, uint256 fee) = _saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(_msgSender(), amount + fee);
  }

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external virtual onlyFrom("SANFTManager") returns (bool) {
    if (_saleData.isVested(_saleId, fullAmount, remainingAmount, requestedAmount)) {
      _saleData.getSetupById(_saleId).sellingToken.transfer(saOwner, requestedAmount);
      return true;
    } else {
      return false;
    }
  }

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get("SaleData");
    if (addr != address(_saleData)) {
      _saleData = ISaleData(addr);
    }
  }
}
