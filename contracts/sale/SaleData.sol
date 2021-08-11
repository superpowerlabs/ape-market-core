// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISaleData.sol";
import "./ISaleFactory.sol";
import "../nft/ISANFTManager.sol";
import "./ITokenRegistry.sol";
import "../registry/RegistryUser.sol";

contract SaleData is ISaleData, RegistryUser {
  using SafeMath for uint256;

  address private _apeWallet;

  modifier onlySaleOwner(uint16 saleId) {
    require(_msgSender() == _saleDB.getSetupById(saleId).owner, "SaleData: caller is not the owner");
    _;
  }

  modifier onlySale(uint16 saleId) {
    require(_msgSender() == _saleDB.getSetupById(saleId).saleAddress, "SaleData: caller is not a sale");
    _;
  }

  modifier onlySaleFactory() {
    require(_msgSender() == address(_saleFactory), "SaleData: only SaleFactory can call this function");
    _;
  }

  constructor(address registry, address apeWallet_) RegistryUser(registry) {
    _apeWallet = apeWallet_;
  }

  ISANFTManager private _sanftmanager;
  ITokenRegistry private _tokenRegistry;
  ISaleFactory private _saleFactory;
  ISaleDB private _saleDB;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get("SANFTManager");
    if (addr != address(_sanftmanager)) {
      _sanftmanager = ISANFTManager(addr);
    }
    addr = _get("TokenRegistry");
    if (addr != address(_tokenRegistry)) {
      _tokenRegistry = ITokenRegistry(addr);
    }
    addr = _get("SaleFactory");
    if (addr != address(_saleFactory)) {
      _saleFactory = ISaleFactory(addr);
    }
    addr = _get("SaleDB");
    if (addr != address(_saleDB)) {
      _saleDB = ISaleDB(addr);
    }
  }

  function apeWallet() external view override returns (address) {
    return _apeWallet;
  }

  function updateApeWallet(address apeWallet_) external override onlyOwner {
    _apeWallet = apeWallet_;
  }

  function increaseSaleId() external override onlySaleFactory {
    _saleDB.increaseSaleId();
  }

  /**
   * @dev Validate and pack a VestingStep[]. It must be called by the dApp during the configuration of the Sale setup. The same code can be executed in Javascript, but running a function on a smart contract guarantees future compatibility.
   * @param vestingStepsArray The array of VestingStep
   */
  function validateAndPackVestingSteps(ISaleDB.VestingStep[] memory vestingStepsArray)
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
        _saleDB.getSetupById(saleId).vestingSteps,
        _saleDB.getExtraVestingStepsById(saleId),
        _saleDB.getSetupById(saleId).tokenListTimestamp,
        block.timestamp
      );
  }

  function setUpSale(
    uint16 saleId,
    address saleAddress,
    ISaleDB.Setup memory setup,
    uint256[] memory extraVestingSteps,
    address paymentToken
  ) external override onlySaleFactory {
    setup.saleAddress = saleAddress;
    setup.paymentTokenId = _tokenRegistry.idByAddress(paymentToken);
    if (setup.paymentTokenId == 0) {
      setup.paymentTokenId = _tokenRegistry.register(paymentToken);
    }
    _saleDB.initSale(saleId, setup,extraVestingSteps);
  }

  function paymentTokenById(uint8 id) public view override returns (address) {
    return _tokenRegistry.addressById(id);
  }

  function makeTransferable(uint16 saleId) external override onlySaleOwner(saleId) {
    _saleDB.makeTransferable(saleId);
  }

  function fromValueToTokensAmount(uint16 saleId, uint32 value) public view override returns (uint120) {
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    return uint120(uint256(value).mul(10**setup.sellingToken.decimals()).mul(setup.pricingToken).div(setup.pricingPayment));
  }

  function fromTokensAmountToValue(uint16 saleId, uint120 amount) public view override returns (uint32) {
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
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
    uint120 remainingAmount = fromValueToTokensAmount(saleId, _saleDB.getSetupById(saleId).totalValue);
    _saleDB.updateRemainingAmount(saleId, remainingAmount);
    uint256 fee = uint256(remainingAmount).mul(_saleDB.getSetupById(saleId).tokenFeePercentage).div(100);
    return (_saleDB.getSetupById(saleId).sellingToken, _saleDB.getSetupById(saleId).owner, uint256(remainingAmount).add(fee));
  }

  // we need the bridge to keep Sale.sol small
  function getSetupById(uint16 saleId) external view override returns (ISaleDB.Setup memory) {
    return _saleDB.getSetupById(saleId);
  }

  function approveInvestor(
    uint16 saleId,
    address investor,
    uint32 amount
  ) external virtual override onlySaleOwner(saleId) {
    _saleDB.setApproval(saleId, investor, amount);
  }

  function setInvest(
    uint16 saleId,
    address investor,
    uint256 amount
  ) external virtual override onlySale(saleId) returns (uint256, uint256) {
    uint approved = _saleDB.getApproval(saleId, investor);
    require(amount <= approved, "SaleData: Amount is above approved amount");
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    require(amount >= setup.minAmount, "SaleData: Amount is too low");
    uint256 tokensAmount = fromValueToTokensAmount(saleId, uint32(amount));
    require(tokensAmount <= setup.remainingAmount, "SaleData: Not enough tokens available");
    if (amount == approved) {
      _saleDB.deleteApproval(saleId, investor);
    } else {
      _saleDB.setApproval(saleId, investor, uint32(uint256(approved).sub(amount)));
    }
    uint256 decimals = IERC20Min(paymentTokenById(setup.paymentTokenId)).decimals();
    uint256 payment = amount.mul(decimals).mul(setup.pricingPayment).div(setup.pricingToken);
    uint256 buyerFee = payment.mul(setup.paymentFeePercentage).div(100);
    uint256 sellerFee = tokensAmount.mul(setup.tokenFeePercentage).div(100);
    setup.remainingAmount = uint120(uint256(setup.remainingAmount).sub(tokensAmount));
    _sanftmanager.mintInitialTokens(investor, setup.saleAddress, tokensAmount, sellerFee);
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
    ISaleDB.Setup memory setup = _saleDB.getSetupById(saleId);
    require(amount <= setup.remainingAmount, "SaleData: Cannot withdraw more than remaining");
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
    if (_saleDB.getSetupById(saleId).tokenListTimestamp == 0) return 0;
    uint256 vested = vestedPercentage(saleId);
    return uint256(remainingAmount).sub(vested == 100 ? 0 : uint256(fullAmount).mul(100 - vested).div(100));
  }

  function triggerTokenListing(uint16 saleId) external virtual override onlySaleOwner(saleId) {
    _saleDB.triggerTokenListing(saleId);
  }
}
