// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

//import "hardhat/console.sol";

import "../utils/LevelAccess.sol";
import "./ISaleData.sol";

interface ISAStorage {

  struct SA {
    address sale;
    uint256 remainingAmount;
    uint256 vestedPercentage;
  }
}

contract Sale is LevelAccess {

  using SafeMath for uint256;

//  ISaleData.VestingStep[] _vestingSchedule;
//  ISaleData.Setup private _setup;

  ISaleData private _saleData;

  uint public constant SALE_OWNER_LEVEL = 3;
  uint private _saleId;
  address private _apeWallet;
  mapping(address => uint256) private _approvedAmounts;

  constructor(address apeWallet_, address saleDataAddress){
    _apeWallet = apeWallet_;
    _saleData = ISaleData(saleDataAddress);
  }

  function initialize(ISaleData.Setup memory setup_, ISaleData.VestingStep[] memory schedule) external {
    _saleId = _saleData.setUpSale(setup_, schedule);
    grantLevel(SALE_OWNER_LEVEL, setup_.owner);
  }

  function getSetup() public view returns (ISaleData.Setup memory) {
    return _saleData.getSaleById(_saleId);
  }

  function getPaymentToken() external view returns (address){
    return address(_saleData.getSaleById(_saleId).paymentToken);
  }

  function changeApeWallet(address apeWallet_) external
  onlyLevel(SALE_OWNER_LEVEL) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view
  returns (address) {
    return _apeWallet;
  }

  function makeTransferable() external {
    _saleData.makeTransferable(_saleId);
  }

  function isTransferable() external view returns (bool){
    return _saleData.getSaleById(_saleId).isTokenTransferable;
  }

  function normalize(uint32 amount) public view returns (uint) {
    return _saleData.normalize(_saleId, amount);
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual
  onlyLevel(SALE_OWNER_LEVEL) {
    (ERC20Min sellingToken, address owner, uint amount) = _saleData.setLaunch(_saleId);
    sellingToken.transferFrom(owner, address(this), amount);
  }

  // Sale creator calls this function to approve investor.
  // can be called repeated. unused amount can be forfeited by setting it to 0
  function approveInvestor(address investor, uint256 amount) external virtual
  onlyLevel(SALE_OWNER_LEVEL) {
    _approvedAmounts[investor] = amount;
  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external virtual {
    require(_approvedAmounts[msg.sender] >= amount, "Sale: Amount if above approved amount");
    ISaleData.Setup memory setup = _saleData.getSaleById(_saleId);
    (uint tokenPayment, uint buyerFee, uint sellerFee) = _saleData.setInvest(_saleId, amount);
//    console.log("tokenPayment", tokenPayment);
    setup.paymentToken.transferFrom(msg.sender, _apeWallet, buyerFee);
    setup.paymentToken.transferFrom(msg.sender, address(this), tokenPayment);
    // mint NFT
    ISAToken nft = ISAToken(setup.satoken);
    nft.mint(msg.sender, amount);
    nft.mint(_apeWallet, sellerFee);
    _approvedAmounts[msg.sender] = _approvedAmounts[msg.sender].sub(amount);
//    console.log("Sale: Paying buyer fee", buyerFee);
//    console.log("Sale: Paying seller fee", sellerFee);
  }

  function withdrawPayment(uint256 amount) external virtual
  onlyLevel(SALE_OWNER_LEVEL) {
    _saleData.getSaleById(_saleId).paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual
  onlyLevel(SALE_OWNER_LEVEL) {
    (ERC20Min sellingToken, uint fee) = _saleData.setWithdrawToken(_saleId, amount);
    sellingToken.transfer(msg.sender, amount + fee);
  }

  function triggerTokenListing() external virtual
  onlyLevel(SALE_OWNER_LEVEL) {
    _saleData.triggerTokenListing(_saleId);
  }

  function isTokenListed() external virtual view returns (bool) {
    return (_saleData.getSaleById(_saleId).tokenListTimestamp != 0);
  }

  function vest(address sa_owner, ISAStorage.SA memory sa) external virtual
  returns (uint, uint){
    ISaleData.Setup memory setup = _saleData.getSaleById(_saleId);
    require(msg.sender == address(setup.satoken), "Sale: only SAToken can call vest");
    (uint vestedPercentage, uint vestedAmount) = _saleData.setVest(_saleId, sa.vestedPercentage, sa.remainingAmount);
    setup.sellingToken.transfer(sa_owner, vestedAmount);
    return (vestedPercentage, vestedAmount);
  }
}