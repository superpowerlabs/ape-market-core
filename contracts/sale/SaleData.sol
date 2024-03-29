// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISaleData.sol";
import "./ISaleFactory.sol";
import "../nft/ISANFTManager.sol";
import "./ITokenRegistry.sol";
import "../registry/RegistryUser.sol";
import "../access/OwnedByMultiSigOwner.sol";

import {SaleLib} from "../libraries/SaleLib.sol";

contract SaleData is ISaleData, RegistryUser, OwnedByMultiSigOwner {
  using SafeMath for uint256;

  bytes32 internal constant _SANFT_MANAGER = keccak256("SANFTManager");
  bytes32 internal constant _SALE_FACTORY = keccak256("SaleFactory");
  bytes32 internal constant _SALE_DB = keccak256("SaleDB");
  bytes32 internal constant _TOKEN_REGISTRY = keccak256("TokenRegistry");

  address private _apeWallet;
  address private _daoWallet;

  modifier onlySaleOwner(uint16 saleId) {
    require(_msgSender() == _saleDB.getSetupById(saleId).owner, "SaleData: caller is not the owner");
    _;
  }

  modifier onlySale(uint16 saleId) {
    require(_msgSender() == _saleDB.getSetupById(saleId).saleAddress, "SaleData: caller is not a sale");
    _;
  }

  modifier onlySaleFactory() {
    require(_msgSender() == address(_saleFactory), "SaleData: only SaleFactory can call this function");
    _;
  }

  modifier onlySANFTManager() {
    require(_msgSender() == address(_sanftManager), "SaleData: only SANFTManager can call this function");
    _;
  }

  constructor(address registry, address apeWallet_) RegistryUser(registry) {
    updateApeWallet(apeWallet_);
  }

  ISANFTManager private _sanftManager;
  ITokenRegistry private _tokenRegistry;
  ISaleFactory private _saleFactory;
  ISaleDB private _saleDB;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get(_SANFT_MANAGER);
    if (addr != address(_sanftManager)) {
      _sanftManager = ISANFTManager(addr);
    }
    addr = _get(_TOKEN_REGISTRY);
    if (addr != address(_tokenRegistry)) {
      _tokenRegistry = ITokenRegistry(addr);
    }
    addr = _get(_SALE_FACTORY);
    if (addr != address(_saleFactory)) {
      _saleFactory = ISaleFactory(addr);
    }
    addr = _get(_SALE_DB);
    if (addr != address(_saleDB)) {
      _saleDB = ISaleDB(addr);
    }
  }

  function apeWallet() external view override returns (address) {
    return _apeWallet;
  }

  function updateApeWallet(address apeWallet_) public override onlyMultiSigOwner {
    _apeWallet = apeWallet_;
    emit ApeWalletUpdated(apeWallet_);
    if (!_requiresMultiSigOwner) {
      // after first execution it requires a multi sig owner
      _requiresMultiSigOwner = true;
    }
  }

  function updateDAOWallet(address daoWallet_) public override {
    if (_daoWallet == address(0)) {
      require(_msgSender() == owner(), "Forbidden");
    } else {
      require(_msgSender() == _daoWallet, "Forbidden");
    }
    _daoWallet = daoWallet_;
    emit DaoWalletUpdated(daoWallet_);
  }

  function increaseSaleId() external override onlySaleFactory {
    _saleDB.increaseSaleId();
  }

  function vestedPercentage(uint16 saleId) public view override returns (uint8) {
    return
      SaleLib.calculateVestedPercentage(
        _saleDB.getSetupById(saleId).vestingSteps,
        _saleDB.getExtraVestingStepsById(saleId),
        _saleDB.getSetupById(saleId).tokenListTimestamp,
        block.timestamp
      );
  }

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external override onlySaleFactory {
    setup.saleAddress = saleAddress;
    setup.paymentTokenId = _tokenRegistry.idByAddress(paymentToken);
    if (setup.paymentTokenId == 0) {
      setup.paymentTokenId = _tokenRegistry.register(paymentToken);
    }
    _saleDB.initSale(saleId, setup, extraVestingSteps);
    emit SaleSetup(saleId, saleAddress);
  }

  function paymentTokenById(uint8 id) public view override returns (address) {
    return _tokenRegistry.addressById(id);
  }

  function makeTransferable(uint16 saleId) external override onlySaleOwner(saleId) {
    _saleDB.makeTransferable(saleId);
  }

  function fromValueToTokensAmount(uint16 saleId, uint32 value) public view override returns (uint256) {
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    return uint256(value).mul(10**setup.sellingToken.decimals()).mul(setup.pricingToken).div(setup.pricingPayment);
  }

  function fromTokensAmountToValue(uint16 saleId, uint120 amount) public view override returns (uint32) {
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    return uint32(uint256(amount).mul(setup.pricingPayment).div(setup.pricingToken).div(10**setup.sellingToken.decimals()));
  }

  function getTokensAmountAndFeeByValue(uint16 saleId, uint32 value) public view override returns (uint256, uint256) {
    uint256 amount = fromValueToTokensAmount(saleId, value);
    uint256 fee = amount.mul(_saleDB.getSetupById(saleId).tokenFeePoints).div(10000);
    return (amount, fee);
  }

  function setLaunchOrExtension(uint16 saleId, uint256 value)
    external
    virtual
    override
    onlySale(saleId)
    returns (IERC20Min, uint256)
  {
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    (uint256 amount, uint256 fee) = getTokensAmountAndFeeByValue(saleId, value != 0 ? uint32(value) : setup.totalValue);
    _saleDB.updateRemainingAmount(saleId, uint120(amount), true);
    if (value == 0) {
      emit SaleLaunched(saleId, setup.totalValue, uint120(amount));
    } else {
      emit SaleExtended(saleId, uint32(value), uint120(amount));
    }
    _sanftManager.mint(_apeWallet, saleId, fee);
    return (setup.sellingToken, amount.add(fee));
  }

  // we need the bridge to keep Sale.sol small
  function getSetupById(uint16 saleId) external view override returns (ISaleDB.Setup memory) {
    return _saleDB.getSetupById(saleId);
  }

  function approveInvestors(
    uint16 saleId,
    address[] memory investors,
    uint32[] memory uSDValueAmounts
  ) external virtual override onlySaleOwner(saleId) {
    require(investors.length == uSDValueAmounts.length, "SaleData: amounts inconsistent with investors length");
    for (uint256 i = 0; i < investors.length; i++) {
      _saleDB.setApproval(saleId, investors[i], uSDValueAmounts[i]);
    }
  }

  function setInvest(
    uint16 saleId,
    address investor,
    uint256 usdValueAmount
  ) external virtual override onlySale(saleId) returns (uint256, uint256) {
    uint256 approved = _saleDB.getApproval(saleId, investor);
    require(usdValueAmount <= approved, "SaleData: Amount is above approved amount");
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    require(setup.futureTokenSaleId == 0, "SaleData: Cannot invest in a swapping sale");
    require(usdValueAmount >= setup.minAmount, "SaleData: Amount is too low");
    uint256 tokensAmount = fromValueToTokensAmount(saleId, uint32(usdValueAmount));
    uint256 feeOnRemainingAmount = uint256(setup.remainingAmount).mul(setup.tokenFeePoints).div(10000);
    require(tokensAmount <= uint256(setup.remainingAmount).sub(feeOnRemainingAmount), "SaleData: Not enough tokens available");
    if (usdValueAmount == approved) {
      _saleDB.deleteApproval(saleId, investor);
    } else {
      _saleDB.setApproval(saleId, investor, uint32(uint256(approved).sub(usdValueAmount)));
    }
    uint256 decimals = IERC20Min(paymentTokenById(setup.paymentTokenId)).decimals();
    uint256 paymentTokenAmount = usdValueAmount.mul(10**decimals);
    uint256 buyerFee = paymentTokenAmount.mul(setup.paymentFeePoints).div(10000);
    setup.remainingAmount = uint120(uint256(setup.remainingAmount).sub(tokensAmount));
    _sanftManager.mint(investor, saleId, tokensAmount);
    return (paymentTokenAmount, buyerFee);
  }

  function setWithdrawToken(uint16 saleId, uint256 amount) external virtual override onlySale(saleId) returns (IERC20Min) {
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    require(amount <= setup.remainingAmount, "SaleData: Cannot withdraw more than remaining");
    setup.remainingAmount = uint120(uint256(setup.remainingAmount).sub(amount));
    return setup.sellingToken;
  }

  function vestedAmount(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount
  ) public view virtual override returns (uint256) {
    if (_saleDB.getSetupById(saleId).tokenListTimestamp == 0) return 0;
    uint256 vested = vestedPercentage(saleId);
    return uint256(remainingAmount).sub(uint256(fullAmount).mul(100 - vested).div(100));
  }

  function triggerTokenListing(uint16 saleId) external virtual override onlySaleOwner(saleId) {
    _saleDB.triggerTokenListing(saleId);
    emit TokenListed(saleId);
  }

  function emergencyTriggerTokenListing(uint16 saleId) external virtual override {
    //     this is an emergency function, to be called only in case
    //     the seller blocks the listing forever,
    //     locking forever the tokens in the sale.
    require(_daoWallet != address(0) && _msgSender() == _daoWallet, "Only the DAO can call this");
    _saleDB.triggerTokenListing(saleId);
    emit TokenForcefullyListed(saleId);
  }

  function setSwap(uint16 saleId, uint120 amount) external virtual override onlySANFTManager {
    _saleDB.updateRemainingAmount(saleId, amount, false);
  }
}
