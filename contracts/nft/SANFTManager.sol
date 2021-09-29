// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISANFTManager.sol";
import "./ISANFT.sol";
import "../sale/ISale.sol";
import "../sale/ISaleData.sol";
import "../user/IProfile.sol";
import "../sale/IERC20Min.sol";

import "../registry/RegistryUser.sol";


contract SANFTManager is ISANFTManager, RegistryUser {
  using SafeMath for uint256;

  bytes32 internal constant _SANFT = keccak256("SANFT");
  bytes32 internal constant _SALE_DATA = keccak256("SaleData");
  bytes32 internal constant _SALE_DB = keccak256("SaleDB");
  bytes32 internal constant _PROFILE = keccak256("Profile");

  address public apeWallet;
  IERC20Min private _feeToken;

  // we use a permillage to be able to charge, for example, the 2.5%. In this case the value would be 25
  uint256 public feePoints;

  modifier onlySANFT() {
    require(_msgSender() == address(_sanft), "SANFTManager: only SANFT can call this function");
    _;
  }

  modifier onlyTokenOwner(uint256 tokenId) {
    require(_sanft.ownerOf(tokenId) == _msgSender(), "SANFTManager: only the owner can do this operation");
    _;
  }

  constructor(
    address registry,
    address apeWallet_,
    uint256 feePoints_
  ) RegistryUser(registry) {
    updatePayments(apeWallet_, feePoints_);
  }

  ISANFT private _sanft;
  ISaleData private _saleData;
  IProfile private _profile;
  ISaleDB private _saleDB;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get(_SANFT);
    if (addr != address(_sanft)) {
      _sanft = ISANFT(addr);
    }
    addr = _get(_SALE_DATA);
    if (addr != address(_saleData)) {
      _saleData = ISaleData(addr);
    }
    addr = _get(_PROFILE);
    if (addr != address(_profile)) {
      _profile = IProfile(addr);
    }
    addr = _get(_SALE_DB);
    if (addr != address(_saleDB)) {
      _saleDB = ISaleDB(addr);
    }
  }

  function updatePayments(address apeWallet_, uint256 feePoints_) public virtual override onlyOwner {
    apeWallet = apeWallet_;
    feePoints = feePoints_;
  }

  /**
   * @dev Allow to withdraw vested tokens.
   * @param tokenId The id of the SANFT
   * @param amounts The amount of tokens to be withdrawn for any SA
   */
  function withdraw(
    uint256 tokenId,
    uint256[] memory amounts // <<
  ) external virtual override onlySANFT {
    address tokenOwner = _sanft.ownerOf(tokenId);
    ISANFT.SA[] memory bundle = _sanft.getBundle(tokenId);
    require(amounts.length == bundle.length, "SANFTManager: amounts inconsistent with SAs");
    bool done;
    for (uint256 i = 0; i < bundle.length; i++) {
        ISaleDB.Setup memory setup = _saleData.getSetupById(bundle[i].saleId);
        if (setup.tokenListTimestamp != 0) {
          ISale sale = ISale(_saleDB.getSaleAddressById(bundle[i].saleId));
          uint256 vestedAmount = sale.vest(tokenOwner, bundle[i].fullAmount, bundle[i].remainingAmount, amounts[i]);
          if (vestedAmount > 0) {
            bundle[i].remainingAmount = uint120(uint256(bundle[i].remainingAmount).sub(vestedAmount));
            done = true;
          }
        }
    }
    if (done) {
      // puts the modified SA in a new NFT and burns the existing one
      _createNewToken(_sanft.ownerOf(tokenId), bundle);
      _sanft.burn(tokenId);
    } else {
      revert("SANFTManager: Cannot withdraw not available tokens");
    }
  }

  /**
   * @dev Get the withdrawable amounts for fully or partially vested tokens
   * @param tokenId The id of the SANFT
   */
  function withdrawables(uint256 tokenId) external view virtual override onlySANFT returns (uint16[] memory, uint256[] memory) {
    ISANFT.SA[] memory bundle = _sanft.getBundle(tokenId);
    uint16[] memory saleIds = new uint16[](bundle.length);
    uint256[] memory amounts = new uint256[](bundle.length);
    for (uint256 i = 0; i < bundle.length; i++) {
      saleIds[i] = bundle[i].saleId;
      amounts[i] = _saleData.vestedAmount(bundle[i].saleId, bundle[i].fullAmount, bundle[i].remainingAmount);
    }
    return (saleIds, amounts);
  }

  function _createNewToken(address owner, ISANFT.SA[] memory bundle) internal {
    uint256 nextId = _sanft.nextTokenId();
    bool minted;
    for (uint256 i = 0; i < bundle.length; i++) {
      if (bundle[i].remainingAmount > 0) {
        if (!minted) {
          _sanft.mint(owner, bundle[i].saleId, bundle[i].fullAmount, bundle[i].remainingAmount);
          minted = true;
        } else {
          _sanft.addSAToBundle(nextId, ISANFT.SA(bundle[i].saleId, bundle[i].fullAmount, bundle[i].remainingAmount));
        }
      }
    }
  }

  function beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external view override onlySANFT {
    if (address(_profile) == address(0) || !_profile.areAccountsAssociated(from, to)) {
      // check if any sale is not transferable:
      ISANFT.SA[] memory bundle = _sanft.getBundle(tokenId);
      for (uint256 i = 0; i < bundle.length; i++) {
        if (!_saleData.getSetupById(bundle[i].saleId).isTokenTransferable) {
          revert("SANFT: token not transferable");
        }
      }
    }
  }

  function mint(
    address receiver,
    uint16 saleId,
    uint256 amount
  ) external override {
    require(_msgSender() == address(_saleData), "SANFTManager: only SaleData can call this function");
    _sanft.mint(receiver, saleId, uint120(amount), uint120(amount));
  }

  function areMergeable(uint256[] memory tokenIds)
    public
    view
    virtual
    override
    returns (
      bool,
      string memory,
      uint256
    )
  {
    if (tokenIds.length < 2) return (false, "Cannot merge a single NFT", 0);
    address tokenOwner = _sanft.ownerOf(tokenIds[0]);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (_sanft.ownerOf(tokenIds[i]) != tokenOwner) return (false, "All NFTs must be owned by same owner", 0);
    }
    uint256 counter;
    ISANFT.SA[] memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) return (false, "NFT cannot be merged with itself", 0);
      }
      bundle = _sanft.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount != 0) {
          counter++;
          break;
        }
      }
    }
    if (counter == 1) return (false, "Not enough not empty SAs", 0);
    return (true, "NFTs are mergeable", counter);
  }

  function merge(uint256[] memory tokenIds) external virtual override onlyTokenOwner(tokenIds[0]) {
    (bool isMergeable, string memory message, uint256 counter) = areMergeable(tokenIds);
    require(isMergeable, string(abi.encodePacked("SANFTManager: ", message)));
    ISANFT.SA[] memory bundle;
    uint256 index = 0;
    ISANFT.SA[] memory newBundle = new ISANFT.SA[](counter);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _sanft.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount == 0) {
          continue;
        }
        bool matched = false;
        for (uint256 k = 0; k < newBundle.length; k++) {
          if (bundle[j].saleId == newBundle[k].saleId) {
            newBundle[k].fullAmount += bundle[j].fullAmount;
            newBundle[k].remainingAmount += bundle[j].remainingAmount;
            matched = true;
            break;
          }
        }
        if (!matched) {
          newBundle[index++] = bundle[j];
        }
      }
      _sanft.burn(tokenIds[i]);
    }
    ISANFT.SA[] memory feeBundle;
    (newBundle, feeBundle) = _applyFeesToBundle(newBundle);

    _createNewToken(_msgSender(), newBundle);
    _createNewToken(apeWallet, feeBundle);
  }

  function _applyFeesToBundle(ISANFT.SA[] memory bundle) internal view returns (ISANFT.SA[] memory, ISANFT.SA[] memory) {
    ISANFT.SA[] memory apeBundle = new ISANFT.SA[](bundle.length);
    for (uint256 i = 0; i < bundle.length; i++) {
      apeBundle[i].saleId = bundle[i].saleId;
      uint256 fullAmount = uint256(bundle[i].fullAmount);
      uint256 remainingAmount = uint256(bundle[i].remainingAmount);
      // calculates the fee
      uint256 fee = remainingAmount.mul(feePoints).div(10000);
      // this is necessary to maintain correct vested percentages
      uint256 feeToFullAmount = fullAmount.mul(feePoints).div(10000);
      bundle[i].fullAmount = uint120(fullAmount.sub(feeToFullAmount));
      bundle[i].remainingAmount = uint120(remainingAmount.sub(fee));
      apeBundle[i].fullAmount = uint120(feeToFullAmount);
      apeBundle[i].remainingAmount = uint120(fee);
    }
    return (bundle, apeBundle);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) external virtual override onlyTokenOwner(tokenId) {

    ISANFT.SA[] memory bundle = _sanft.getBundle(tokenId);
    ISANFT.SA[] memory feeBundle;
    (bundle, feeBundle) = _applyFeesToBundle(bundle);
    _createNewToken(apeWallet, feeBundle);
    require(keptAmounts.length == bundle.length, "SANFTManager: length of SAs does not match split");
    ISANFT.SA[] memory newBundleA = new ISANFT.SA[](keptAmounts.length);
    ISANFT.SA[] memory newBundleB = new ISANFT.SA[](keptAmounts.length);
    uint256 a;
    uint256 b;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(
        bundle[i].remainingAmount >= keptAmounts[i],
        "SANFTManager: kept amounts cannot be larger that remaining amounts"
      );
      uint120 fullAmountKept = uint120(uint256(bundle[i].fullAmount).mul(keptAmounts[i]).div(bundle[i].remainingAmount));
      uint120 otherFullAmount = bundle[i].fullAmount - fullAmountKept;
      if (keptAmounts[i] != 0) {
        newBundleA[a++] = ISANFT.SA(bundle[i].saleId, fullAmountKept, uint120(keptAmounts[i]));
      }
      if (bundle[i].remainingAmount != uint120(keptAmounts[i])) {
        newBundleB[b++] = ISANFT.SA(bundle[i].saleId, otherFullAmount, bundle[i].remainingAmount - uint120(keptAmounts[i]));
      }
    }
    if (a > 0 || b > 0) {
      // when burning an item, the last item is moved to
      // the position of the item to be deleted, and then last item deleted.
      // The following arangement makes that, if A is split to B, C, B will replace
      // A and C will be at the end.
      if (a > 0) _createNewToken(_msgSender(), newBundleA);
      _sanft.burn(tokenId);
      if (b > 0) _createNewToken(_msgSender(), newBundleB);
    } else {
      revert("SANFTManager; split failed");
    }
  }

  function swap(uint256 tokenId, uint16 tokenSaleId) external virtual override onlyTokenOwner(tokenId) returns (bool) {
    uint16 futureTokenSaleId = _saleData.getSetupById(tokenSaleId).futureTokenSaleId;
    require(futureTokenSaleId > 0, "No swap is supported");
    ISANFT.SA[] memory bundle = _sanft.getBundle(tokenId);
    bool swapped = false;
    for (uint256 i = 0; i < bundle.length; i++) {
      if (bundle[i].saleId == futureTokenSaleId) {
        bundle[i].saleId = tokenSaleId;
        _saleData.setSwap(tokenSaleId, bundle[i].fullAmount);
        swapped = true;
      }
    }
    if (swapped) {
      _sanft.burn(tokenId);
      _createNewToken(_msgSender(), bundle);
    }
    return swapped;
  }
}
