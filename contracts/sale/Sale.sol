// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

//import "hardhat/console.sol";

import "../nft/ISAStorage.sol";
import "./ISaleData.sol";

contract Sale {

  using SafeMath for uint256;

  ISaleData private _saleData;

  uint public saleId;
  address private _apeWallet;
  
  modifier onlySaleOwner() {
    require(msg.sender == _saleData.getSetupById(saleId).owner, "Sale: caller is not the owner");
    _;
  }

  constructor(address apeWallet_, address saleDataAddress){
    _apeWallet = apeWallet_;
    _saleData = ISaleData(saleDataAddress);
  }

  function initialize(ISaleData.Setup memory setup_, ISaleData.VestingStep[] memory schedule) external {
    saleId = _saleData.setUpSale(setup_, schedule);
  }

  function changeApeWallet(address apeWallet_) external
  onlySaleOwner {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view
  returns (address) {
    return _apeWallet;
  }

  function isTransferable() external view returns (bool){
    return _saleData.getSetupById(saleId).isTokenTransferable;
  }

  // Sale creator calls this function to start the sale.
  // Precondition: Sale creator needs to approve cap + fee Amount of token before calling this
  function launch() external virtual
  onlySaleOwner {
    (ERC20Min sellingToken, address owner, uint amount) = _saleData.setLaunch(saleId);
    sellingToken.transferFrom(owner, address(this), amount);
  }

  // Sale creator calls this function to approve investor.
  // can be called repeated. unused amount can be forfeited by setting it to 0
//  function approveInvestor(address investor, uint256 amount) external virtual
//  onlySaleOwner {
//    _saleData.approveInvestor(saleId, investor, amount);
//  }

  // Invest amount into the sale.
  // Investor needs to approve the payment + fee amount need for purchase before calling this
  function invest(uint256 amount) external virtual {
    ISaleData.Setup memory setup = _saleData.getSetupById(saleId);
    (uint tokenPayment, uint buyerFee, uint sellerFee) = _saleData.setInvest(saleId, msg.sender, amount);
//    console.log("tokenPayment", tokenPayment);
    setup.paymentToken.transferFrom(msg.sender, _apeWallet, buyerFee);
    setup.paymentToken.transferFrom(msg.sender, address(this), tokenPayment);
    // mint NFT
    ISAToken nft = ISAToken(setup.satoken);
    nft.mint(msg.sender, amount);
    nft.mint(_apeWallet, sellerFee);
//    console.log("Sale: Paying buyer fee", buyerFee);
//    console.log("Sale: Paying seller fee", sellerFee);
  }

  function withdrawPayment(uint256 amount) external virtual
  onlySaleOwner {
    _saleData.getSetupById(saleId).paymentToken.transfer(msg.sender, amount);
  }

  function withdrawToken(uint256 amount) external virtual
  onlySaleOwner {
    (ERC20Min sellingToken, uint fee) = _saleData.setWithdrawToken(saleId, amount);
    sellingToken.transfer(msg.sender, amount + fee);
  }

  function vest(address sa_owner, ISAStorage.SA memory sa) external virtual
  returns (uint, uint){
    ISaleData.Setup memory setup = _saleData.getSetupById(saleId);
    require(msg.sender == address(setup.satoken), "Sale: only SAToken can call vest");
    (uint vestedPercentage, uint vestedAmount) = _saleData.setVest(saleId, sa.vestedPercentage, sa.remainingAmount);
    setup.sellingToken.transfer(sa_owner, vestedAmount);
    return (vestedPercentage, vestedAmount);
  }
}