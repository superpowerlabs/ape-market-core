// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/LevelAccess.sol";
import "./ISaleData.sol";

contract SaleData is ISaleData, LevelAccess {

  using SafeMath for uint;
  uint public constant MANAGER_LEVEL = 2;
  uint public constant ADMIN_LEVEL = 3;

  mapping (uint => VestingStep[]) private _vestingSchedules;
  mapping (uint => Setup) private _setups;
  mapping(uint => mapping(address => uint256)) private _approvedAmounts;
  uint private _lastId = 0;

  modifier onlySaleOwner(uint saleId) {
    require(msg.sender == _setups[saleId].owner, "Sale: caller is not the owner");
    _;
  }

  function setUpSale(Setup memory setup, VestingStep[] memory schedule) external override
  onlyLevel(MANAGER_LEVEL) returns (uint){
    _setups[_lastId] = setup;
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(schedule[i].percentage > schedule[i - 1].percentage, "Sale: Vest percentage should be monotonic increasing");
      }
      _vestingSchedules[_lastId].push(schedule[i]);
    }
    require(schedule[schedule.length - 1].percentage == 100, "Sale: Vest percentage should end at 100");
    return _lastId++;
  }

  function makeTransferable(uint saleId) external override
  onlySaleOwner(saleId) {
    // it cannot be changed back
    if (!_setups[saleId].isTokenTransferable) {
      _setups[saleId].isTokenTransferable = true;
    }
  }

  function setLaunch(uint saleId) external virtual override
  onlyLevel(MANAGER_LEVEL) returns (IERC20Min, address, uint){
    uint capAmount = normalize(saleId, _setups[saleId].capAmount);
    uint256 fee = capAmount.mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount = capAmount;
    return (_setups[saleId].sellingToken, _setups[saleId].owner, capAmount.add(fee));
  }

  function normalize(uint saleId, uint64 amount) public view override returns (uint) {
    uint decimals = _setups[saleId].sellingToken.decimals();
    return uint256(amount).mul(10 ** decimals).div(1000);
  }

  function denormalize(address sellingToken, uint64 amount) public view override returns (uint) {
    // this should be called by the DApp to send the Setup object
    IERC20Min token = IERC20Min(sellingToken);
    uint decimals = token.decimals();
    return uint256(amount).mul(1000).div(10 ** decimals);
  }

  function getSetupById(uint saleId) external view override
  returns (Setup memory){
    return _setups[saleId];
  }

  function approveInvestor(uint saleId, address investor, uint256 amount) external virtual override
  onlySaleOwner(saleId)  {
    _approvedAmounts[saleId][investor] = amount;
  }

  function setInvest(uint saleId, address investor, uint256 amount) external virtual override
  onlyLevel(MANAGER_LEVEL) returns (uint, uint, uint) {
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

  function setWithdrawToken(uint saleId, uint256 amount) external virtual override
  onlyLevel(MANAGER_LEVEL) returns (IERC20Min, uint){
    // we cannot simply relying on the transfer to do the check, since some of the
    // token are sold to investors.
    require(amount <= _setups[saleId].remainingAmount, "Sale: Cannot withdraw more than remaining");
    uint capAmount = normalize(saleId, _setups[saleId].capAmount);
    uint256 fee = capAmount.mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount -= amount;
    return (_setups[saleId].sellingToken, fee);
  }

  function setVest(uint saleId, uint256 lastVestedPercentage, uint256 lockedAmount) external virtual override
  returns (uint, uint){
    uint256 vestedPercentage = getVestedPercentage(saleId);
    uint256 vestedAmount = getVestedAmount(vestedPercentage, lastVestedPercentage, lockedAmount);
    return (vestedPercentage, vestedAmount);
  }

  function triggerTokenListing(uint saleId) external virtual override
  onlySaleOwner(saleId) {
    require(_setups[saleId].tokenListTimestamp == 0, "Sale: Token already listed");
    _setups[saleId].tokenListTimestamp = uint64(block.timestamp);
  }

  function grantManagerLevel(address saleAddress) public override
  onlyLevel(ADMIN_LEVEL) {
    levels[saleAddress] = MANAGER_LEVEL;
    emit LevelSet(MANAGER_LEVEL, saleAddress, msg.sender);
  }

  function getVestedPercentage(uint saleId) public view override
  onlyLevel(MANAGER_LEVEL) returns (uint256) {
    Setup memory setup = _setups[saleId];
    VestingStep[] memory vs = _vestingSchedules[saleId];
    if (setup.tokenListTimestamp == 0) {
      return 0;
    }
    uint256 vestedPercentage;
    for (uint256 i = 0; i < vs.length; i++) {
      uint256 ts = uint256(setup.tokenListTimestamp).add(vs[i].timestamp);
      if (ts > block.timestamp) {
        break;
      }
      vestedPercentage = vs[i].percentage;
    }
    return vestedPercentage;
  }

  function getVestedAmount(uint256 vestedPercentage, uint256 lastVestedPercentage, uint256 lockedAmount) public view override
  onlyLevel(MANAGER_LEVEL) returns (uint256) {
    uint256 vestedAmount;
    if (vestedPercentage == 100) {
      vestedAmount = lockedAmount;
    } else {
      vestedAmount = lockedAmount.mul(vestedPercentage.sub(lastVestedPercentage))
      .div(100 - lastVestedPercentage);
    }
    return vestedAmount;
  }

}