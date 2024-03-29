// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../nft/ISANFT.sol";
import "./ISaleData.sol";
import "./ISale.sol";
import "./IERC20Min.sol";
import "../registry/IApeRegistry.sol";
import "../libraries/SafeERC20Min.sol";

contract Sale is ISale, Ownable {
  using SafeMath for uint256;
  using SafeERC20Min for IERC20Min;

  bytes32 internal constant _SALE_DATA = keccak256("SaleData");
  bytes32 internal constant _SANFT_MANAGER = keccak256("SANFTManager");

  uint16 private _saleId;
  IApeRegistry private _apeRegistry;

  modifier onlyFromManager() {
    require(
      _msgSender() == _apeRegistry.get(_SANFT_MANAGER),
      string(abi.encodePacked("RegistryUser: only SANFTManager can call this function"))
    );
    _;
  }

  constructor(uint16 saleId_, address registry) {
    _saleId = saleId_;
    _apeRegistry = IApeRegistry(registry);
  }

  function saleId() external view override returns (uint16) {
    return _saleId;
  }

  function _getSaleData() internal view returns (ISaleData) {
    return ISaleData(_apeRegistry.get(_SALE_DATA));
  }

  function _isSaleOwner(ISaleData saleData) internal view {
    require(_msgSender() == saleData.getSetupById(_saleId).owner, "Sale: caller is not the owner");
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual override {
    ISaleData saleData = _getSaleData();
    _isSaleOwner(saleData);
    (IERC20Min sellingToken, uint256 amount) = saleData.setLaunchOrExtension(_saleId, 0);
    sellingToken.safeTransferFrom(_msgSender(), address(this), amount);
  }

  // Sale creator calls this function to extend a sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function extend(uint256 extraValue) external virtual override {
    ISaleData saleData = _getSaleData();
    _isSaleOwner(saleData);
    (IERC20Min sellingToken, uint256 extraAmount) = saleData.setLaunchOrExtension(_saleId, extraValue);
    sellingToken.safeTransferFrom(_msgSender(), address(this), extraAmount);
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint32 usdValueAmount) external virtual override {
    ISaleData saleData = _getSaleData();
    ISaleDB.Setup memory setup = saleData.getSetupById(_saleId);
    require(setup.futureTokenSaleId == 0, "Cannot invest in swap");
    (uint256 paymentTokenAmount, uint256 buyerFee) = saleData.setInvest(_saleId, _msgSender(), usdValueAmount);
    IERC20Min paymentToken = IERC20Min(saleData.paymentTokenById(setup.paymentTokenId));
    paymentToken.safeTransferFrom(_msgSender(), saleData.apeWallet(), buyerFee);
    paymentToken.safeTransferFrom(_msgSender(), address(this), paymentTokenAmount);
  }

  function withdrawPayment(uint256 amount) external virtual override {
    ISaleData saleData = _getSaleData();
    _isSaleOwner(saleData);
    IERC20Min paymentToken = IERC20Min(saleData.paymentTokenById(saleData.getSetupById(_saleId).paymentTokenId));
    if (amount == 0) {
      amount = paymentToken.balanceOf(address(this));
    }
    paymentToken.transfer(_msgSender(), amount);
  }

  function withdrawToken(uint256 amount) external virtual override {
    ISaleData saleData = _getSaleData();
    _isSaleOwner(saleData);
    IERC20Min sellingToken = saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(_msgSender(), amount);
  }

  function vest(
    address saOwner,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external virtual override onlyFromManager returns (uint256) {
    ISaleData saleData = _getSaleData();
    uint256 vestedAmount = saleData.vestedAmount(_saleId, fullAmount, remainingAmount);
    if (requestedAmount == 0) {
      requestedAmount = vestedAmount;
    }
    if (requestedAmount <= vestedAmount) {
      saleData.getSetupById(_saleId).sellingToken.transfer(saOwner, requestedAmount);
      return requestedAmount;
    } else {
      return 0;
    }
  }
}
