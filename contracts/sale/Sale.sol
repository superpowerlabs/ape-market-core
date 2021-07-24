// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

import "./ISale.sol";
//import "./SaleLib.sol";
import "../utils/LevelAccess.sol";

contract Sale is ISale, LevelAccess {

  using SafeMath for uint256;

  uint public constant SALE_OWNER_LEVEL = 3;

  VestingStep[] _vestingSchedule;

  Setup private _setup;
  address private _apeWallet;
  mapping(address => uint256) private _approvedAmounts;

  constructor(Setup memory setup_, VestingStep[] memory schedule, address apeWallet_){
    _setup = setup_;
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(schedule[i].percentage > schedule[i - 1].percentage, "Sale: Vest percentage should be monotonic increasing");
      }
      _vestingSchedule.push(schedule[i]);
    }
    require(schedule[schedule.length - 1].percentage == 100, "Sale: Vest percentage should end at 100");
    _apeWallet = apeWallet_;
    // set permissions and set custom revert message
    grantLevel(SALE_OWNER_LEVEL, _setup.owner);
  }

  function getSetup() public view returns (Setup memory, VestingStep[] memory) {
    return (_setup, _vestingSchedule);
  }

  function getPaymentToken() external view override returns (address){
    return address(_setup.paymentToken);
  }

  function changeApeWallet(address apeWallet_) external override
  onlyLevel(SALE_OWNER_LEVEL) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view override
  returns (address) {
    return _apeWallet;
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual override
  onlyLevel(SALE_OWNER_LEVEL) {
    uint256 fee = _setup.capAmount.mul(_setup.tokenFeePercentage).div(100);
    _setup.sellingToken.transferFrom(_setup.owner, address(this), _setup.capAmount.add(fee));
    _setup.remainingAmount = _setup.capAmount;
  }

  // Sale creator calls this function to approve investor.
  // can be called repeated. unused amount can be forfeited by setting it to 0
  function approveInvestor(address investor, uint256 amount) external virtual override
  onlyLevel(SALE_OWNER_LEVEL) {
    _approvedAmounts[investor] = amount;
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external virtual override {
    require(amount >= _setup.minAmount, "Sale: Amount is too low");
    require(amount <= _setup.remainingAmount, "Sale: Amount is too high");
    require(_approvedAmounts[msg.sender] >= amount, "Sale: Amount if above approved amount");
    uint256 tokenPayment = amount.mul(_setup.pricingPayment).div(_setup.pricingToken);
    uint256 buyerFee = tokenPayment.mul(_setup.paymentFeePercentage).div(100);
    uint256 sellerFee = amount.mul(_setup.tokenFeePercentage).div(100);
    _setup.paymentToken.transferFrom(msg.sender, _apeWallet, buyerFee);
    _setup.paymentToken.transferFrom(msg.sender, address(this), tokenPayment);
    // mint NFT
    ISAToken nft = ISAToken(_setup.satoken);
    nft.mint(msg.sender, amount);
    nft.mint(_apeWallet, sellerFee);
    _setup.remainingAmount = _setup.remainingAmount.sub(amount);
    _approvedAmounts[msg.sender] = _approvedAmounts[msg.sender].sub(amount);
    console.log("Sale: Paying buyer fee", buyerFee);
    console.log("Sale: Paying seller fee", sellerFee);
  }

  function withdrawPayment(uint256 amount) external virtual override
  onlyLevel(SALE_OWNER_LEVEL) {
    _setup.paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual override
  onlyLevel(SALE_OWNER_LEVEL) {
    // we cannot simply relying on the transfer to do the check, since some of the
    // token are sold to investors.
    require(amount <= _setup.remainingAmount, "Sale: Cannot withdraw more than remaining");
    uint256 fee = _setup.capAmount.mul(_setup.tokenFeePercentage).div(100);
    _setup.sellingToken.transfer(msg.sender, amount + fee);
    _setup.remainingAmount -= amount;
  }

  function triggerTokenListing() external virtual override
  onlyLevel(SALE_OWNER_LEVEL) {
    require(_setup.tokenListTimestamp == 0, "Sale: Token already listed");
    _setup.tokenListTimestamp = block.timestamp;
  }

  function isTokenListed() external virtual view override returns (bool) {
    return (_setup.tokenListTimestamp != 0);
  }

  function getVestedPercentage() public virtual view override returns (uint256) {
//    return SaleLib.getVestedPercentage(_setup, _vestingSchedule);
    if (_setup.tokenListTimestamp == 0) {// token not listed yet!
      return 0;
    }
    VestingStep[] storage vs = _vestingSchedule;
    uint256 vestedPercentage;
    for (uint256 i = 0; i < vs.length; i++) {
      uint256 ts = _setup.tokenListTimestamp.add(vs[i].timestamp);
      console.log("vesting ts", ts);
      if (ts > block.timestamp) {
        break;
      }
      vestedPercentage = vs[i].percentage;
    }
    console.log("vested percentage", vestedPercentage);
    return vestedPercentage;
  }

  function getVestedAmount(
    uint256 vestedPercentage,
    uint256 lastVestedPercentage,
    uint256 lockedAmount) public virtual view override returns (uint256) {
//    return SaleLib.getVestedAmount(vestedPercentage, lastVestedPercentage, lockedAmount);
    uint256 vestedAmount;
    if (vestedPercentage == 100) {
      vestedAmount = lockedAmount;
    } else {
      vestedAmount = lockedAmount.mul(vestedPercentage.sub(lastVestedPercentage))
      .div(100 - lastVestedPercentage);
    }
    return vestedAmount;
  }

  function vest(address sa_owner, ISAStorage.SA memory sa) external virtual override
  returns (uint, uint){
    require(msg.sender == address(_setup.satoken), "Sale: only SAToken can call vest");
    uint256 vestedPercentage = getVestedPercentage();
    // TODO: Maybe this can be exploited passing an arbitrary sa?
    uint256 vestedAmount = getVestedAmount(vestedPercentage, sa.vestedPercentage, sa.remainingAmount);
    _setup.sellingToken.transfer(sa_owner, vestedAmount);
    return (vestedPercentage, vestedAmount);
  }
}