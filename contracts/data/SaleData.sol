// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/LevelAccess.sol";
import "./ISaleData.sol";

import "hardhat/console.sol";

contract SaleData is ISaleData, LevelAccess {
  using SafeMath for uint256;
  uint256 public constant SALE_LEVEL = 1;
  uint256 public constant ADMIN_LEVEL = 2;

  uint256 private _nextId;
  address private _apeWallet;

  mapping(uint256 => address) private _salesById;

  mapping(uint256 => VestingStep[]) private _vestingSchedules;
  mapping(uint256 => Setup) private _setups;
  mapping(uint256 => mapping(address => uint256)) private _approvedAmounts;

  modifier onlySaleOwner(uint256 saleId) {
    require(msg.sender == _setups[saleId].owner, "Sale: caller is not the owner");
    _;
  }

  constructor(address apeWallet_) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view override returns (address) {
    return _apeWallet;
  }

  function updateApeWallet(address apeWallet_) external override onlyLevel(OWNER_LEVEL) {
    _apeWallet = apeWallet_;
  }

  function nextSaleId() external view override returns (uint256) {
    return _nextId;
  }

  function increaseSaleId() external override onlyLevel(ADMIN_LEVEL) {
    _nextId++;
  }

  function isLegitSale(address sale) external view override returns (bool) {
    return levels[sale] == SALE_LEVEL;
  }

  function grantManagerLevel(address saleAddress) public override onlyLevel(ADMIN_LEVEL) {
    levels[saleAddress] = SALE_LEVEL;
    emit LevelSet(SALE_LEVEL, saleAddress, msg.sender);
  }

  function getSaleAddressById(uint256 saleId) external view override returns (address) {
    return _salesById[saleId];
  }

  function setUpSale(
    uint256 saleId,
    address saleAddress,
    Setup memory setup,
    VestingStep[] memory schedule
  ) external override onlyLevel(SALE_LEVEL) {
    require(_setups[saleId].owner == address(0), "SaleData: id has already been used");
    require(saleId < _nextId, "SaleData: invalid id");
    _setups[saleId] = setup;
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(
          schedule[i].percentage > schedule[i - 1].percentage,
          "Sale: Vest percentage should be monotonic increasing"
        );
      }
      _vestingSchedules[saleId].push(schedule[i]);
    }
    require(schedule[schedule.length - 1].percentage == 100, "Sale: Vest percentage should end at 100");
    _salesById[saleId] = saleAddress;
  }

  function makeTransferable(uint256 saleId) external override onlySaleOwner(saleId) {
    // it cannot be changed back
    if (!_setups[saleId].isTokenTransferable) {
      _setups[saleId].isTokenTransferable = true;
    }
  }

  function setLaunch(uint256 saleId)
    external
    virtual
    override
    onlyLevel(SALE_LEVEL)
    returns (
      IERC20Min,
      address,
      uint256
    )
  {
    uint256 capAmount = normalize(saleId, _setups[saleId].capAmount);
    uint256 fee = capAmount.mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount = capAmount;
    return (_setups[saleId].sellingToken, _setups[saleId].owner, capAmount.add(fee));
  }

  function normalize(uint256 saleId, uint64 amount) public view override returns (uint256) {
    uint256 decimals = _setups[saleId].sellingToken.decimals();
    return uint256(amount).mul(10**decimals).div(1000);
  }

  function denormalize(address sellingToken, uint64 amount) public view override returns (uint256) {
    // this should be called by the DApp to send the Setup object
    IERC20Min token = IERC20Min(sellingToken);
    uint256 decimals = token.decimals();
    return uint256(amount).mul(1000).div(10**decimals);
  }

  function getSetupById(uint256 saleId) external view override returns (Setup memory) {
    return _setups[saleId];
  }

  function approveInvestor(
    uint256 saleId,
    address investor,
    uint256 amount
  ) external virtual override onlySaleOwner(saleId) {
    _approvedAmounts[saleId][investor] = amount;
  }

  function setInvest(
    uint256 saleId,
    address investor,
    uint256 amount
  )
    external
    virtual
    override
    onlyLevel(SALE_LEVEL)
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    require(_approvedAmounts[saleId][investor] >= amount, "Sale: Amount if above approved amount");
    require(amount >= normalize(saleId, _setups[saleId].minAmount), "Sale: Amount is too low");
    require(amount <= _setups[saleId].remainingAmount, "Sale: Amount is too high");
    _approvedAmounts[saleId][investor] = _approvedAmounts[saleId][investor].sub(amount);
    uint256 tokenPayment = amount.mul(_setups[saleId].pricingPayment).div(_setups[saleId].pricingToken);
    uint256 buyerFee = tokenPayment.mul(_setups[saleId].paymentFeePercentage).div(100);
    uint256 sellerFee = amount.mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount = _setups[saleId].remainingAmount.sub(amount);
    return (tokenPayment, buyerFee, sellerFee);
  }

  function setWithdrawToken(uint256 saleId, uint256 amount)
    external
    virtual
    override
    onlyLevel(SALE_LEVEL)
    returns (IERC20Min, uint256)
  {
    // we cannot simply relying on the transfer to do the check, since some of the
    // token are sold to investors.
    require(amount <= _setups[saleId].remainingAmount, "Sale: Cannot withdraw more than remaining");
    uint256 capAmount = normalize(saleId, _setups[saleId].capAmount);
    uint256 fee = capAmount.mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount -= amount;
    return (_setups[saleId].sellingToken, fee);
  }

  function setVest(
    uint256 saleId,
    uint128 lastVestedPercentage,
    uint256 lockedAmount
  ) external virtual override returns (uint128, uint256) {
    uint128 vestedPercentage = getVestedPercentage(saleId);
    uint256 vestedAmount = getVestedAmount(vestedPercentage, lastVestedPercentage, lockedAmount);
    return (vestedPercentage, vestedAmount);
  }

  function triggerTokenListing(uint256 saleId) external virtual override onlySaleOwner(saleId) {
    require(_setups[saleId].tokenListTimestamp == 0, "Sale: Token already listed");
    _setups[saleId].tokenListTimestamp = uint64(block.timestamp);
  }

  function getVestedPercentage(uint256 saleId) public view override onlyLevel(SALE_LEVEL) returns (uint128) {
    Setup memory setup = _setups[saleId];
    VestingStep[] memory vs = _vestingSchedules[saleId];
    if (setup.tokenListTimestamp == 0) {
      return 0;
    }
    uint128 vestedPercentage;
    for (uint256 i = 0; i < vs.length; i++) {
      uint256 ts = uint256(setup.tokenListTimestamp).add(vs[i].timestamp);
      if (ts > block.timestamp) {
        break;
      }
      vestedPercentage = vs[i].percentage;
    }
    return vestedPercentage;
  }

  function getVestedAmount(
    uint256 vestedPercentage,
    uint256 lastVestedPercentage,
    uint256 lockedAmount
  ) public view override onlyLevel(SALE_LEVEL) returns (uint256) {
    uint256 vestedAmount;
    if (vestedPercentage == 100) {
      vestedAmount = lockedAmount;
    } else {
      vestedAmount = lockedAmount.mul(vestedPercentage.sub(lastVestedPercentage)).div(100 - lastVestedPercentage);
    }
    return vestedAmount;
  }
}
