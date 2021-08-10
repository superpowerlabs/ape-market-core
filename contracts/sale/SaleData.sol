// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISaleData.sol";
import "../nft/ISANFTManager.sol";
import "./ITokenRegistry.sol";
import "../registry/RegistryUser.sol";

contract SaleData is ISaleData, RegistryUser {
  using SafeMath for uint256;

  uint256 private _nextId = 1;
  address private _apeWallet;

  mapping(uint256 => Setup) private _setups;
  mapping(address => uint256) private _saleIdByAddress;
  mapping(uint256 => uint256[]) private _extraVestingSteps;

  // both the following in USD
  mapping(uint16 => mapping(address => uint32)) private _approvedAmounts;
  mapping(uint16 => mapping(address => uint32)) private _valuesInEscrow;

  modifier onlySaleOwner(uint16 saleId) {
    require(_msgSender() == _setups[uint256(saleId)].owner, "Sale: caller is not the owner");
    _;
  }

  modifier onlySale(uint16 saleId) {
    require(_msgSender() == _setups[uint256(saleId)].saleAddress, "Sale: caller is not a sale");
    _;
  }

  constructor(address registry, address apeWallet_) RegistryUser(registry) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view override returns (address) {
    return _apeWallet;
  }

  function updateApeWallet(address apeWallet_) external override onlyOwner {
    _apeWallet = apeWallet_;
  }

  function nextSaleId() external view override returns (uint256) {
    return _nextId;
  }

  function increaseSaleId() external override onlyFrom("SaleFactory") {
    _nextId++;
  }

  function getSaleIdByAddress(address sale) external view override returns (uint16) {
    return uint16(_saleIdByAddress[sale]);
  }

  function getSaleAddressById(uint16 saleId) external view override returns (address) {
    return _setups[uint256(saleId)].saleAddress;
  }

  /**
   * @dev Validate and pack a VestingStep[]. It must be called by the dApp during the configuration of the Sale setup. The same code can be executed in Javascript, but running a function on a smart contract guarantees future compatibility.
   * @param vestingStepsArray The array of VestingStep
   */
  function validateAndPackVestingSteps(VestingStep[] memory vestingStepsArray)
    external
    pure
    override
    returns (uint256[] memory, string memory)
  {
    uint256 len = vestingStepsArray.length / 15;
    uint256[] memory errorCode = new uint256[](1);
    if (vestingStepsArray.length % 15 > 0) len++;
    uint256[] memory steps = new uint256[](len);
    uint256 j;
    uint256 k;
    for (uint256 i = 0; i < vestingStepsArray.length; i++) {
      if (vestingStepsArray[i].waitTime > 999) {
        errorCode[0] = 4;
        return (errorCode, "waitTime cannot be more than 999 days");
      }
      if (i > 0) {
        if (vestingStepsArray[i].percentage <= vestingStepsArray[i - 1].percentage) {
          errorCode[0] = 1;
          return (errorCode, "Vest percentage should be monotonic increasing");
        }
        if (vestingStepsArray[i].waitTime <= vestingStepsArray[i - 1].waitTime) {
          errorCode[0] = 2;
          return (errorCode, "waitTime should be monotonic increasing");
        }
      }
      steps[j] += ((vestingStepsArray[i].percentage - 1) + 100 * (vestingStepsArray[i].waitTime % (10**3))) * (10**(5 * k));
      if (i % 15 == 14) {
        j++;
        k = 0;
      } else {
        k++;
      }
    }
    if (vestingStepsArray[vestingStepsArray.length - 1].percentage != 100) {
      errorCode[0] = 3;
      return (errorCode, "Vest percentage should end at 100");
    }
    return (steps, "Success");
  }

  /**
   * @dev Calculate the vesting percentage, based on values in Setup.vestingSteps and extraVestingSteps[]
   * @param vestingSteps The vales of Setup.VestingSteps, first 15 events
   * @param extraVestingSteps The array of extra vesting steps
   * @param tokenListTimestamp The timestamp when token has been listed
   * @param currentTimestamp The current timestamp (it'd be, most likely, block.timestamp)
   */
  function calculateVestedPercentage(
    uint256 vestingSteps,
    uint256[] memory extraVestingSteps,
    uint256 tokenListTimestamp,
    uint256 currentTimestamp
  ) public pure override returns (uint8) {
    for (uint256 i = extraVestingSteps.length + 1; i >= 1; i--) {
      uint256 steps = i > 1 ? extraVestingSteps[i - 2] : vestingSteps;
      for (uint256 k = 16; k >= 1; k--) {
        uint256 step = steps / (10**(5 * (k - 1)));
        if (step != 0) {
          uint256 ts = (step / 100);
          uint256 percentage = (step % 100) + 1;
          if ((ts * 24 * 3600) + tokenListTimestamp <= currentTimestamp) {
            return uint8(percentage);
          }
        }
        steps %= (10**(5 * (k - 1)));
      }
    }
    return 0;
  }

  function vestedPercentage(uint16 saleId) public view override returns (uint8) {
    return
      calculateVestedPercentage(
        _setups[saleId].vestingSteps,
        _extraVestingSteps[saleId],
        _setups[saleId].tokenListTimestamp,
        block.timestamp
      );
  }

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external override onlyFrom("SaleFactory") {
    uint256 sId = uint256(saleId);
    require(_setups[sId].owner == address(0), "SaleData: id has already been used");
    require(saleId < _nextId, "SaleData: invalid id");
    setup.saleAddress = saleAddress;
    ITokenRegistry registry = ITokenRegistry(_get("TokenRegistry"));
    setup.paymentTokenId = registry.idByAddress(paymentToken);
    if (setup.paymentTokenId == 0) {
      setup.paymentTokenId = registry.register(paymentToken);
    }
    _setups[sId] = setup;
    _saleIdByAddress[saleAddress] = saleId;
    _extraVestingSteps[uint256(saleId)] = extraVestingSteps;
  }

  function paymentTokenById(uint8 id) public view override returns (address) {
    return ITokenRegistry(_get("TokenRegistry")).addressById(id);
  }

  function makeTransferable(uint16 saleId) external override onlySaleOwner(saleId) {
    // cannot be changed back
    uint256 sId = uint256(saleId);
    if (!_setups[sId].isTokenTransferable) {
      _setups[sId].isTokenTransferable = true;
    }
  }

  function fromValueToTokensAmount(uint16 saleId, uint32 value) public view override returns (uint120) {
    Setup memory setup = _setups[saleId];
    return uint120(uint256(value).mul(10**setup.sellingToken.decimals()).mul(setup.pricingToken).div(setup.pricingPayment));
  }

  function fromTokensAmountToValue(uint16 saleId, uint120 amount) public view override returns (uint32) {
    Setup memory setup = _setups[saleId];
    return uint32(uint256(amount).mul(setup.pricingPayment).div(setup.pricingToken).div(10**setup.sellingToken.decimals()));
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
    _setups[saleId].remainingAmount = fromValueToTokensAmount(saleId, _setups[saleId].totalValue);
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
  ) external virtual override onlySale(saleId) returns (uint256, uint256) {
    require(amount <= _approvedAmounts[saleId][investor], "SaleData: Amount is above approved amount");
    Setup memory setup = _setups[saleId];
    require(amount >= setup.minAmount, "SaleData: Amount is too low");
    uint256 tokensAmount = fromValueToTokensAmount(saleId, uint32(amount));
    require(tokensAmount <= setup.remainingAmount, "SaleData: Not enough tokens available");
    if (amount == _approvedAmounts[saleId][investor]) {
      delete _approvedAmounts[saleId][investor];
    } else {
      _approvedAmounts[saleId][investor] = uint32(uint256(_approvedAmounts[saleId][investor]).sub(amount));
    }
    uint256 decimals = IERC20Min(paymentTokenById(setup.paymentTokenId)).decimals();
    uint256 payment = amount.mul(decimals).mul(setup.pricingPayment).div(setup.pricingToken);
    uint256 buyerFee = payment.mul(setup.paymentFeePercentage).div(100);
    uint256 sellerFee = tokensAmount.mul(setup.tokenFeePercentage).div(100);
    setup.remainingAmount = uint120(uint256(setup.remainingAmount).sub(tokensAmount));
    ISANFTManager(_get("SANFTManager")).mintInitialTokens(investor, setup.saleAddress, tokensAmount, sellerFee);
    return (payment, buyerFee);
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
    Setup memory setup = _setups[saleId];
    require(amount <= setup.remainingAmount, "Sale: Cannot withdraw more than remaining");
    uint256 fee = uint256(setup.capAmount).mul(setup.tokenFeePercentage).div(100);
    setup.remainingAmount = uint120(uint256(setup.remainingAmount).sub(amount));
    return (setup.sellingToken, fee);
  }

  function isVested(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount,
    uint256 requestedAmount
  ) external view virtual override returns (bool) {
    return requestedAmount <= vestedAmount(saleId, fullAmount, remainingAmount);
  }

  function vestedAmount(
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount
  ) public view virtual override returns (uint256) {
    if (_setups[saleId].tokenListTimestamp == 0) return 0;
    uint256 vested = vestedPercentage(saleId);
    return uint256(remainingAmount).sub(vested == 100 ? 0 : uint256(fullAmount).mul(100 - vested).div(100));
  }

  function triggerTokenListing(uint16 saleId) external virtual override onlySaleOwner(saleId) {
    require(_setups[saleId].tokenListTimestamp == 0, "Sale: Token already listed");
    _setups[saleId].tokenListTimestamp = uint32(block.timestamp);
  }
}
