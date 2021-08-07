// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/AddressMin.sol";
import "./ISaleData.sol";
import "./ITokenRegistry.sol";
import "../registry/RegistryUser.sol";

import "hardhat/console.sol";

contract SaleData is ISaleData, RegistryUser {
  using SafeMath for uint256;

  uint256 private _nextId = 1;
  address private _apeWallet;
  ISAToken private _saToken;

  mapping(uint16 => Setup) private _setups;
  mapping(address => uint16) private _saleIdByAddress;

  // both the following in USD
  mapping(uint16 => mapping(address => uint32)) private _approvedAmounts;
  mapping(uint16 => mapping(address => uint32)) private _valuesInEscrow;

  modifier onlySaleOwner(uint16 saleId) {
    require(msg.sender == _setups[saleId].owner, "Sale: caller is not the owner");
    _;
  }

  modifier onlySale(uint16 saleId) {
    require(msg.sender == _setups[saleId].saleAddress, "Sale: caller is not a sale");
    _;
  }

  constructor(address apeWallet_, address registry) RegistryUser(registry) {
    _apeWallet = apeWallet_;
  }

  function getSAToken() external view override returns (ISAToken) {
    return _saToken;
  }

  function apeWallet() external view override returns (address) {
    return _apeWallet;
  }

  function updateApeWallet(address apeWallet_) external override onlyOwner {
    _apeWallet = apeWallet_;
  }

  function updateFees(
    uint16 saleId,
    uint8 tokenFeePercentage,
    uint8 extraFeePercentage,
    uint8 paymentFeePercentage,
    uint8 changeFeePercentage
  ) external override onlyOwner {
    require(_setups[saleId].saleAddress != address(0), "SaleData: sale does not exist");
    // Values can be at most 100 (the full percentage)
    // and any value > 100 is skipped.
    // This way, the function can be used to update only one field
    if (tokenFeePercentage < 101) _setups[saleId].tokenFeePercentage = tokenFeePercentage;
    if (extraFeePercentage < 101) _setups[saleId].extraFeePercentage = extraFeePercentage;
    if (paymentFeePercentage < 101) _setups[saleId].paymentFeePercentage = paymentFeePercentage;
    if (changeFeePercentage < 101) _setups[saleId].changeFeePercentage = changeFeePercentage;
  }

  function nextSaleId() external view override returns (uint256) {
    return _nextId;
  }

  function increaseSaleId() external override onlyFrom("SaleFactory") {
    _nextId++;
  }

  function getSaleIdByAddress(address sale) external view override returns (uint16) {
    return _saleIdByAddress[sale];
  }

  function getSaleAddressById(uint16 saleId) external view override returns (address) {
    return _setups[saleId].saleAddress;
  }

  /**
* @dev Validate a VestingStep[].
   It can be called by the dApp during the configuration of the Sale setup.
* @param vestingStepsArray The array of VestingStep
*/
  function validateVestingSteps(VestingStep[] memory vestingStepsArray) external pure override returns (bool, string memory) {
    for (uint256 i = 0; i < vestingStepsArray.length; i++) {
      if (i > 0) {
        if (vestingStepsArray[i].percentage <= vestingStepsArray[i - 1].percentage)
          return (false, "Vest percentage should be monotonic increasing");
        if (vestingStepsArray[i].waitTime <= vestingStepsArray[i - 1].waitTime)
          return (false, "Timestamps should be monotonic increasing");
      }
    }
    if (vestingStepsArray[vestingStepsArray.length - 1].percentage != 100) return (false, "Vest percentage should end at 100");
    return (true, "Vesting steps are valid");
  }

  /**
 * @dev Packs a VestingStep[] of at most 15 elements in a single uint256. It must
     be called by the dApp to avoid extra computation during the configuration of
     the Sale setup.
 * @param vestingStepsArray The array of VestingStep
 */
  function packVestingSteps(VestingStep[] memory vestingStepsArray) external view override returns (uint256) {
    uint256 steps;
    for (uint256 i = 0; i < vestingStepsArray.length; i++) {
      steps += ((vestingStepsArray[i].percentage - 1) + 100 * (vestingStepsArray[i].waitTime % (10**3))) * (10**(5 * i));
    }
    return steps;
  }

  function calculateVestedPercentage(
    uint256 steps,
    uint256 tokenListTimestamp,
    uint256 currentTimestamp
  ) public view override returns (uint8) {
    for (uint256 k = 16; k >= 1; k--) {
      uint256 step = steps / (10**(5 * (k - 1)));
      if (step != 0) {
        uint256 ts = step / 100;
        uint256 percentage = step % 100;
        if (ts == 99) {
          ts = 100;
        }
        if ((ts * 24 * 3600) + tokenListTimestamp <= currentTimestamp) {
          return uint8(percentage);
        }
      }
      steps %= (10**(5 * (k - 1)));
    }

    return 0;
  }

  function validateSetup(Setup memory setup) public view override returns (bool, string memory) {
    // TODO see what is missed
    if (setup.minAmount > setup.capAmount) return (false, "minAmount larger than capAmount");
    if (setup.capAmount > setup.totalValue) return (false, "capAmount larger than totalValue");
    if (!AddressMin.isContract(address(setup.sellingToken))) return (false, "sellingToken is not a contract");
    return (true, "Setup is valid");
  }

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    Setup memory setup,
    address paymentToken
  ) external override onlyFrom("SaleFactory") {
    require(_setups[saleId].owner == address(0), "SaleData: id has already been used");
    require(saleId < _nextId, "SaleData: invalid id");
    (bool isValid, string memory message) = validateSetup(setup);
    require(isValid, string(abi.encodePacked("SaleData: ", message)));
    setup.saleAddress = saleAddress;
    ITokenRegistry registry = ITokenRegistry(_get("ITokenRegistry"));
    setup.paymentToken = registry.idByAddress(paymentToken);
    if (setup.paymentToken == 0) {
      setup.paymentToken = registry.addToken(paymentToken);
    }
    _setups[saleId] = setup;
    _saleIdByAddress[saleAddress] = saleId;
  }

  function paymentTokenById(uint8 id) external view override returns (address) {
    return ITokenRegistry(_get("ITokenRegistry")).addressById(id);
  }

  function makeTransferable(uint16 saleId) external override onlySaleOwner(saleId) {
    // cannot be changed back
    if (!_setups[saleId].isTokenTransferable) {
      _setups[saleId].isTokenTransferable = true;
    }
  }

  function fromTotalValueToTokensAmount(uint16 saleId) public view override returns (uint120) {
    return
      uint120(
        uint256(_setups[saleId].totalValue).mul(_setups[saleId].sellingToken.decimals()).mul(_setups[saleId].pricingToken).div(
          _setups[saleId].pricingPayment
        )
      );
  }

  function setLaunch(uint16 saleId)
    external
    virtual
    override
    onlySale(saleId)
    returns (
      IERC20Min,
      address,
      uint256
    )
  {
    _setups[saleId].remainingAmount = fromTotalValueToTokensAmount(saleId);
    uint256 fee = uint256(_setups[saleId].remainingAmount).mul(_setups[saleId].tokenFeePercentage).div(100);
    return (_setups[saleId].sellingToken, _setups[saleId].owner, uint256(_setups[saleId].remainingAmount).add(fee));
  }

  function getSetupById(uint16 saleId) external view override returns (Setup memory) {
    return _setups[saleId];
  }

  function approveInvestor(
    uint16 saleId,
    address investor,
    uint32 amount
  ) external virtual override onlySaleOwner(saleId) {
    _approvedAmounts[saleId][investor] = amount;
  }

  function setInvest(
    uint16 saleId,
    address investor,
    uint256 amount
  )
    external
    virtual
    override
    onlySale(saleId)
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    require(amount <= _approvedAmounts[saleId][investor], "SaleData: Amount is above approved amount");
    require(amount >= _setups[saleId].minAmount, "SaleData: Amount is too low");
    // TODO convert
    require(uint120(amount) <= _setups[saleId].remainingAmount, "SaleData: Not enough tokens available");
    if (amount == _approvedAmounts[saleId][investor]) {
      delete _approvedAmounts[saleId][investor];
    } else {
      _approvedAmounts[saleId][investor] = uint32(uint256(_approvedAmounts[saleId][investor]).sub(amount));
    }
    uint256 payment = amount.mul(_setups[saleId].pricingPayment).div(_setups[saleId].pricingToken);
    uint256 buyerFee = payment.mul(_setups[saleId].paymentFeePercentage).div(100);
    uint256 sellerFee = amount.mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount = uint120(uint256(_setups[saleId].remainingAmount).sub(amount));
    return (payment, buyerFee, sellerFee);
  }

  function setWithdrawToken(uint16 saleId, uint256 amount)
    external
    virtual
    override
    onlySale(saleId)
    returns (IERC20Min, uint256)
  {
    // TODO: this function looks wrong

    // we cannot simply relying on the transfer to do the check, since some of the
    // token are sold to investors.
    require(amount <= _setups[saleId].remainingAmount, "Sale: Cannot withdraw more than remaining");
    uint256 fee = uint256(_setups[saleId].capAmount).mul(_setups[saleId].tokenFeePercentage).div(100);
    _setups[saleId].remainingAmount = uint120(uint256(_setups[saleId].remainingAmount).sub(amount));
    return (_setups[saleId].sellingToken, fee);
  }

  function isVested(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external virtual override returns (bool) {
    uint256 tokenListTimestamp = uint256(_setups[saleId].tokenListTimestamp);
    require(tokenListTimestamp != 0, "SaleData: token not listed yet");
    uint256 vestedPercentage = calculateVestedPercentage(_setups[saleId].vestingSteps, tokenListTimestamp, block.timestamp);
    uint256 unvestedAmount = vestedPercentage == 100 ? 0 : uint256(fullAmount).mul(100 - vestedPercentage).div(100);
    return requestedAmount <= uint256(remainingAmount).sub(unvestedAmount);
  }

  function triggerTokenListing(uint16 saleId) external virtual override onlySaleOwner(saleId) {
    require(_setups[saleId].tokenListTimestamp == 0, "Sale: Token already listed");
    _setups[saleId].tokenListTimestamp = uint32(block.timestamp);
  }
}
