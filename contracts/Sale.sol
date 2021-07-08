pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Ape.sol";
import "./SANFT.sol";

contract Sale {

  modifier onlySaleOwner() {
    require(_setup.owner == msg.sender, "Sale: Caller is not sale owner");
    _;
  }

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct VestingStep {
    uint256 timestamp; // how many seconds needs to pass after the token is listed.
    uint256 percentage;
  }

  struct Setup {
    SANFT saNFT;
    uint256 saleBeginTime; // use 0 to start as soon as contract is deployed
    // it's easier than setting up a saleEndTime, especially for testing.
    uint256 duration; // how long in seconds would the sale run.
    uint256 minAmount; // minimum about of token needs to be purchased for each invest transaction
    uint256 capAmount; // the max number, for recording purpose. not changed by contract
    uint256 remainingAmount; // how much token are still up for sale
    uint256 price; //
    IERC20 sellingToken; // the contract address of the token being offered in this sale
    IERC20 paymentToken;
    // owner is the one that creates the sale, receives the payments and
    // pays out tokens.  also the operator.  could be split into multiple
    // roles.  using one for simplification.
    address owner;
    // != 0 means the token has been listed at this timestamp, it will
    // be used as the base for vesting schedule
    uint256 tokenListTimestamp;
    uint256 tokenFeePercentage;
    uint256 paymentFeePercentage;
  }

  VestingStep[] _vestingSchedule;

  Setup private _setup;

  address private _apeAdmin;

  mapping(address => uint256) private _approvedAmounts;

  // cannot have vesting schedule in setup due to solidity's
  // " Copying of type struct Sale.VestingStep memory[] memory to storage not yet supported."
  // Sale has to been deployed by apeOwner, not by token_owner, since
  // we have to verify it's the authentic contract.  Also, we need to
  // make sure apeOwner is setup.
  // Even if we use token_owner as abcSale deployer, it still cannot transfer
  // token directly in constructor and needs approve-and-launch
  constructor(Setup memory setup, VestingStep[] memory schedule) {
    _setup = setup;
    for (uint256 i = 0; i < schedule.length; i++) {
      _vestingSchedule.push(schedule[i]);
    }
    _apeAdmin = msg.sender;
  }

  // Sale creator needs to approve the transfer before calling this
  function launch() external virtual onlySaleOwner {
    _setup.sellingToken.transferFrom(_setup.owner, address(this), _setup.capAmount);
    _setup.remainingAmount = _setup.capAmount;
    if (_setup.saleBeginTime == 0) {
      _setup.saleBeginTime = block.timestamp;
    }
  }

  // can be called repeated. unused amount can be forfeited by setting it to 0
  function approveInvestor(address investor, uint256 amount) external virtual onlySaleOwner {
    _approvedAmounts[investor] = amount;
  }

  // Investor needs to approve the payment before calling this
  function invest(uint256 amount) external virtual {
    require(block.timestamp >= _setup.saleBeginTime, 'Sale: Not started yet');
    require(block.timestamp <= _setup.saleBeginTime + _setup.duration, 'Sale: Ended already');
    require(amount >= _setup.minAmount, 'Sale: Amount is too low');
    require(amount <= _setup.remainingAmount, 'Sale: Amount is too high');
    require(_approvedAmounts[msg.sender] >= amount, "Sale: Amount if above approved amount");
    uint256 totalPayment = amount.mul(_setup.price);
    uint256 buyerFee = totalPayment.mul(_setup.paymentFeePercentage).div(100);
    uint256 sellerFee = amount.mul(_setup.tokenFeePercentage).div(100);
    _setup.paymentToken.transferFrom(msg.sender, _apeAdmin, buyerFee);
    _setup.paymentToken.transferFrom(msg.sender, address(this), totalPayment.sub(buyerFee));
    // mint NFT
    _setup.saNFT.mint(msg.sender, this, amount.sub(sellerFee));
    _setup.saNFT.mint(_apeAdmin, this, sellerFee);
    _setup.remainingAmount = _setup.remainingAmount.sub(amount);
    _approvedAmounts[msg.sender] = _approvedAmounts[msg.sender].sub(amount);
    console.log("Sale: Paying buyer fee", buyerFee);
    console.log("Sale: Paying seller fee", sellerFee);
  }

  function withdrawPayment(uint256 amount) external virtual onlySaleOwner {
    _setup.paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual onlySaleOwner {
    // we cannot simply relying on the transfer to do the check, since some of the
    // token are sold to investors.
    require(amount <= _setup.remainingAmount, "Sale: Cannot withdraw more than remaining");
    _setup.sellingToken.transfer(msg.sender, amount);
    _setup.remainingAmount -= amount;
  }

  function triggerTokenListing() external virtual onlySaleOwner {
    // require(block.timestamp > _setup.saleBeginTime + _setup.duration, "Sale not ended yet");
    require(_setup.tokenListTimestamp == 0, "Sale: Token already listed");
    _setup.tokenListTimestamp = block.timestamp;
  }

  function isTokenListed() external virtual view returns (bool) {
    return (_setup.tokenListTimestamp != 0);
  }

  // for testing only
  function currentBlockTimeStamp() external view returns (uint256) {
    return block.timestamp;
  }

  function getVestedPercentage() public virtual view returns (uint256) {
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
    uint256 lockedAmount) public virtual view returns (uint256) {

    uint256 vestedAmount;
    if (vestedPercentage == 100) {
      vestedAmount = lockedAmount;
    } else {
      vestedAmount = lockedAmount.mul(vestedPercentage.sub(lastVestedPercentage))
      .div(100 - lastVestedPercentage);
    }
    return vestedAmount;
  }

  function vest(address sa_owner, uint256 vestedAmount) external virtual {
    require(msg.sender == address(_setup.saNFT), "Sale: only SANFT can call vest");
    _setup.sellingToken.transfer(sa_owner, vestedAmount);
  }
}