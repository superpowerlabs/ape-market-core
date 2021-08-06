// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/LevelAccess.sol";
import "../utils/AddressMin.sol";
import "./ISaleData.sol";
import "./ITokenRegistry.sol";

import "hardhat/console.sol";

contract SaleData is ISaleData, LevelAccess {
  using SafeMath for uint256;
  uint256 public constant SALE_LEVEL = 1;
  uint256 public constant ADMIN_LEVEL = 2;

  uint256 private _nextId;
  address private _apeWallet;
  ISAToken private _saToken;

  mapping(uint16 => Setup) private _setups;
  mapping(uint16 => uint256[]) private _schedule;

  // both the following in USD
  mapping(uint16 => mapping(address => uint32)) private _approvedAmounts;
  mapping(uint16 => mapping(address => uint32)) private _valuesInEscrow;

  ITokenRegistry private _registry;

  modifier onlySaleOwner(uint16 saleId) {
    require(msg.sender == _setups[saleId].owner, "Sale: caller is not the owner");
    _;
  }

  constructor(
    address apeWallet_,
    address registry,
    address saToken
  ) {
    _apeWallet = apeWallet_;
    _registry = ITokenRegistry(registry);
    _saToken = ISAToken(saToken);
  }

  function getSAToken() external view override returns (ISAToken) {
    return _saToken;
  }

  function apeWallet() external view override returns (address) {
    return _apeWallet;
  }

  function updateApeWallet(address apeWallet_) external override onlyLevel(OWNER_LEVEL) {
    _apeWallet = apeWallet_;
  }

  function updateFees(
    uint16 saleId,
    uint8 tokenFeePercentage,
    uint8 extraFeePercentage,
    uint8 paymentFeePercentage,
    uint8 changeFeePercentage
  ) external override onlyLevel(OWNER_LEVEL) {
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

  function increaseSaleId() external override onlyLevel(ADMIN_LEVEL) {
    _nextId++;
  }

  function isLegitSale(address sale) external view override returns (bool) {
    return levels[sale] == SALE_LEVEL;
  }

  function getSaleAddressById(uint16 saleId) external view override returns (address) {
    return _setups[saleId].saleAddress;
  }

  function _stepMath(VestingStep memory step, uint256 k) internal pure returns (uint256) {
    return (uint256(step.percentage) + 1000 * uint256(step.waitTime % (10**12))) * (10**(12 * k));
  }

  function packVestingSteps(VestingStep[] memory schedule) public view override returns (uint88, uint256[] memory) {
    uint88 firstTwoSteps = uint88(_stepMath(schedule[0], 0) + _stepMath(schedule[1], 1));
    uint256[] memory steps;
    if (schedule.length > 2) {
      uint256 len = (schedule.length - 2) / 7;
      if ((schedule.length - 2) % 7 > 0) len++;
      steps = new uint256[](len);
      uint256 j = 0;
      for (uint256 i = 2; i < schedule.length; i++) {
        uint256 k = (i - 2) % 6;
        steps[j] += _stepMath(schedule[i], k);
        console.log("steps[%s]", j, steps[j]);
        if (k == 5) {
          j++;
        }
      }
    }
    return (firstTwoSteps, steps);
  }

  function calculateVestedPercentage(
    uint88 firstTwoSteps,
    uint256[] memory schedule,
    uint256 tokenListTimestamp,
    uint256 waitTime
  ) public pure override returns (uint256) {
    uint256[] memory steps = new uint256[](schedule.length + 1);
    steps[0] = uint256(firstTwoSteps);
    for (uint256 i = 0; i < schedule.length; i++) {
      steps[i + 1] = schedule[i];
    }
    for (uint256 i = steps.length; i >= 1; i--) {
      uint256 ts0 = steps[i - 1];
      for (uint256 k = 6; k >= 1; k--) {
        uint256 step = ts0 / (10**(12 * (k - 1)));
        if (step != 0) {
          uint256 ts = step / 1000;
          uint256 percentage = step % 1000;
          if (ts + tokenListTimestamp < waitTime) {
            return percentage;
          }
        }
        ts0 %= (10**(12 * (k - 1)));
      }
    }
    return 0;
  }

  function validateSetup(Setup memory setup) public view override returns (bool, string memory) {
    // TODO see what is missed
    if (setup.minAmount > setup.capAmount) return (false, "minAmount larger than capAmount");
    if (setup.capAmount > setup.totalValue) return (false, "capAmount larger than fullAmount");
    if (!AddressMin.isContract(address(setup.sellingToken))) return (false, "sellingToken is not a contract");
    return (true, "Setup is valid");
  }

  function validateVestingSteps(VestingStep[] memory schedule) public pure override returns (bool, string memory) {
    for (uint256 i = 0; i < schedule.length; i++) {
      if (i > 0) {
        if (schedule[i].percentage <= schedule[i - 1].percentage)
          return (false, "Vest percentage should be monotonic increasing");
        if (schedule[i].waitTime <= schedule[i - 1].waitTime) return (false, "Timestamps should be monotonic increasing");
      }
    }
    if (schedule[schedule.length - 1].percentage != 100) return (false, "Vest percentage should end at 100");
    return (true, "Vesting steps are valid");
  }

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    Setup memory setup,
    VestingStep[] memory schedule,
    address paymentToken
  ) external override onlyLevel(ADMIN_LEVEL) {
    require(_setups[saleId].owner == address(0), "SaleData: id has already been used");
    require(saleId < _nextId, "SaleData: invalid id");
    (bool isValid, string memory message) = validateVestingSteps(schedule);
    require(isValid, string(abi.encodePacked("SaleData: ", message)));
    (uint88 firstTwoSteps, uint256[] memory steps) = packVestingSteps(schedule);
    for (uint256 i = 0; i < steps.length; i++) {
      _schedule[saleId].push(steps[i]);
    }
    (isValid, message) = validateSetup(setup);
    require(isValid, string(abi.encodePacked("SaleData: ", message)));
    setup.saleAddress = saleAddress;
    setup.paymentToken = _registry.idByAddress(paymentToken);
    if (setup.paymentToken == 0) {
      setup.paymentToken = _registry.addToken(paymentToken);
    }
    setup.firstTwoVestingSteps = firstTwoSteps;
    _setups[saleId] = setup;
    levels[saleAddress] = SALE_LEVEL;
  }

  function paymentTokenById(uint8 id) external view override returns (address) {
    return _registry.addressById(id);
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
    onlyLevel(SALE_LEVEL)
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
    onlyLevel(SALE_LEVEL)
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
    onlyLevel(SALE_LEVEL)
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
    uint256 vestedPercentage = calculateVestedPercentage(
      _setups[saleId].firstTwoVestingSteps,
      _schedule[saleId],
      tokenListTimestamp,
      block.timestamp
    );
    uint256 unvestedAmount = vestedPercentage == 100 ? 0 : uint256(fullAmount).mul(100 - vestedPercentage).div(100);
    return requestedAmount <= uint256(remainingAmount).sub(unvestedAmount);
  }

  function triggerTokenListing(uint16 saleId) external virtual override onlySaleOwner(saleId) {
    require(_setups[saleId].tokenListTimestamp == 0, "Sale: Token already listed");
    _setups[saleId].tokenListTimestamp = uint32(block.timestamp);
  }
}
