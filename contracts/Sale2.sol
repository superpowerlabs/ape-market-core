// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Ape.sol";
import "./ISAToken.sol";
import "./ISAStorage.sol";

contract Sale2 is AccessControl {

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  bytes32 public constant SALE_OWNER_ROLE = keccak256("SALE_OWNER_ROLE");

  // One step in the vesting schedule
  struct VestingStep {
    uint256 timestamp; // how many seconds needs to pass after the token is listed.
    // how much percentage of token should be vested/unlocked at current step.
    // note it is accumulative, the last step should equal to 100%
    uint256 percentage;
  }

  VestingStep[] _vestingSchedule;

  // This struct contains the basic information about the sale.
  struct Setup {
    ISAToken satoken; // The deployed address of SAToken contract
    uint256 saleBeginTime; // use 0 to start as soon as contract is deployed
    // it's easier than setting up a saleEndTime, especially for testing.
    uint256 duration; // how long in seconds would the sale run.
    uint256 minAmount; // minimum about of token needs to be purchased for each invest transaction
    uint256 capAmount; // the max number, for recording purpose. not changed by contract
    uint256 remainingAmount; // how much token are still up for sale
    // since selling token can be very expensive or very cheap in relation to the payment token
    // and solidity does not have fraction, we use pricing pair to denote the pricing
    // at straight integer lever, disregarding decimals.
    // e.g if pricingToken = 2 and pricingPayment = 5, means 2 token is worth 5 payment at
    // solidity integer level.
    uint256 pricingToken;
    uint256 pricingPayment;
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

  Setup private _setup;
  address private _apeWallet;
  mapping(address => uint256) private _approvedAmounts;

  modifier onlySaleOwner() {
    require(_setup.owner == msg.sender, "Sale: Caller is not sale owner");
    _;
  }

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function setApeWallet(address apeWallet_) external
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view
  returns (address) {
    return _apeWallet;
  }

  function grantRole(bytes32 role, address account) public virtual override {
    if (role == SALE_OWNER_ROLE) {
      require(_setup.owner == account, "Sale: Direct grant not allowed for sale owner");
    }
    super.grantRole(role, account);
  }

  function setup(Setup memory setup_, VestingStep[] memory schedule) external
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _setup = setup_;
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        require(schedule[i].percentage > schedule[i - 1].percentage, "Sale: Vest percentage should be monotonic increasing");
      }
      _vestingSchedule.push(schedule[i]);
    }
    require(schedule[schedule.length - 1].percentage == 100, "Sale: Vest percentage should end at 100");
    grantRole(SALE_OWNER_ROLE, _setup.owner);
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual
  onlyRole(SALE_OWNER_ROLE) {
    uint256 fee = _setup.capAmount.mul(_setup.tokenFeePercentage).div(100);
    _setup.sellingToken.transferFrom(_setup.owner, address(this), _setup.capAmount.add(fee));
    _setup.remainingAmount = _setup.capAmount;
  }

  // Sale creator calls this function to approve investor.
  // can be called repeated. unused amount can be forfeited by setting it to 0
  function approveInvestor(address investor, uint256 amount) external virtual
  onlyRole(SALE_OWNER_ROLE) {
    _approvedAmounts[investor] = amount;
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external virtual {
    require(amount >= _setup.minAmount, "Sale: Amount is too low");
    require(amount <= _setup.remainingAmount, "Sale: Amount is too high");
    require(_approvedAmounts[msg.sender] >= amount, "Sale: Amount if above approved amount");
    uint256 tokenPayment = amount.mul(_setup.pricingPayment).div(_setup.pricingToken);
    uint256 buyerFee = tokenPayment.mul(_setup.paymentFeePercentage).div(100);
    uint256 sellerFee = amount.mul(_setup.tokenFeePercentage).div(100);
    _setup.paymentToken.transferFrom(msg.sender, _apeWallet, buyerFee);
    _setup.paymentToken.transferFrom(msg.sender, address(this), tokenPayment);
    // mint NFT
    _setup.satoken.mint(msg.sender, amount);
    _setup.satoken.mint(_apeWallet, sellerFee);
    _setup.remainingAmount = _setup.remainingAmount.sub(amount);
    _approvedAmounts[msg.sender] = _approvedAmounts[msg.sender].sub(amount);
    console.log("Sale: Paying buyer fee", buyerFee);
    console.log("Sale: Paying seller fee", sellerFee);
  }

  function withdrawPayment(uint256 amount) external virtual
  onlyRole(SALE_OWNER_ROLE) {
    _setup.paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual
  onlyRole(SALE_OWNER_ROLE) {
    // we cannot simply relying on the transfer to do the check, since some of the
    // token are sold to investors.
    require(amount <= _setup.remainingAmount, "Sale: Cannot withdraw more than remaining");
    uint256 fee = _setup.capAmount.mul(_setup.tokenFeePercentage).div(100);
    _setup.sellingToken.transfer(msg.sender, amount + fee);
    _setup.remainingAmount -= amount;
  }

  function triggerTokenListing() external virtual
  onlyRole(SALE_OWNER_ROLE) {
    require(_setup.tokenListTimestamp == 0, "Sale: Token already listed");
    _setup.tokenListTimestamp = block.timestamp;
  }

  function isTokenListed() external virtual view returns (bool) {
    return (_setup.tokenListTimestamp != 0);
  }

  //  // for testing only
  //  function currentBlockTimeStamp() external view returns (uint256) {
  //    return block.timestamp;
  //  }
  //
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

  function vest(address sa_owner, ISAStorage.SA memory sa) external virtual
  returns (uint, uint){
    require(msg.sender == address(_setup.satoken), "Sale: only SAToken can call vest");
    uint256 vestedPercentage = getVestedPercentage();
    uint256 vestedAmount = getVestedAmount(vestedPercentage, sa.vestedPercentage, sa.remainingAmount);

    _setup.sellingToken.transfer(sa_owner, vestedAmount);
    return (vestedPercentage, vestedAmount);
  }
}