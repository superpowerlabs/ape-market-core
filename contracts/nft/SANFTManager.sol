// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISANFTManager.sol";
import "./ISANFT.sol";
import "../sale/ISale.sol";
import "../sale/ISaleData.sol";
import "../user/IProfile.sol";

import "../registry/RegistryUser.sol";

interface IERC20 {
  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function decimals() external view returns (uint8);
}

contract SANFTManager is ISANFTManager, RegistryUser {
  using SafeMath for uint256;

  address public apeWallet;
  IERC20 private _feeToken;

  // we use a permillage to be able to charge, for example, the 2.5%. In this case the value would be 25
  uint256 public feePermillage;

  constructor(
    address registry,
    address apeWallet_,
    uint256 feePermillage_
  ) RegistryUser(registry) {
    updatePayments(apeWallet_, feePermillage_);
  }

  function updatePayments(address apeWallet_, uint256 feePermillage_) public virtual override onlyOwner {
    apeWallet = apeWallet_;
    feePermillage = feePermillage_;
  }

  function _getSANFTIfEqualToMsgSender() internal view returns (ISANFT) {
    address sanft = _get("SANFT");
    // we make the check explicitly, instead of using a modifier, to avoid hashing two times the same string and consume gas
    require(_msgSender() == sanft, "SANFTManager: only SANFT can call this function");
    return ISANFT(sanft);
  }

  /**
   * @dev Allow to withdraw vested tokens.
   * @param tokenId The id of the SANFT
   * @param amounts The amount of tokens to be withdrawn for any SA
   */
  function withdraw(
    uint256 tokenId,
    uint256[] memory amounts // <<
  ) external virtual override {
    ISANFT token = _getSANFTIfEqualToMsgSender();
    address tokenOwner = token.getOwnerOf(tokenId);
    ISaleData saleData = ISaleData(_get("SaleData"));
    ISANFT.SA[] memory sas = token.getBundle(tokenId);
    require(amounts.length == sas.length, "SANFTManager: amounts inconsistent with SAs");
    bool done;
    for (uint256 i = 0; i < sas.length; i++) {
      if (amounts[i] > 0) {
        ISale sale = ISale(saleData.getSaleAddressById(sas[i].saleId));
        if (sale.vest(tokenOwner, sas[i].fullAmount, sas[i].remainingAmount, amounts[i])) {
          sas[i].remainingAmount = uint120(uint256(sas[i].remainingAmount).sub(amounts[i]));
          done = true;
        }
      }
    }
    if (done) {
      // puts the modified SA in a new NFT and burns the existing one
      _createNewToken(token.getOwnerOf(tokenId), sas);
      token.burn(tokenId);
    }
  }

  function _createNewToken(address owner, ISANFT.SA[] memory sas) internal {
    ISANFT token = ISANFT(_get("SANFT"));
    uint256 nextId = token.nextTokenId();
    bool minted;
    for (uint256 i = 0; i < sas.length; i++) {
      if (sas[i].remainingAmount > 0) {
        if (!minted) {
          token.mint(
            owner,
            ISaleData(_get("SaleData")).getSaleAddressById(sas[i].saleId),
            sas[i].fullAmount,
            sas[i].remainingAmount
          );
          minted = true;
        } else {
          token.addSAToBundle(nextId, ISANFT.SA(sas[i].saleId, sas[i].fullAmount, sas[i].remainingAmount));
        }
      }
    }
  }

  function beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external view override {
    if (!IProfile(_get("Profile")).areAccountsAssociated(from, to)) {
      ISANFT token = _getSANFTIfEqualToMsgSender();
      // check if any sale is not transferable:
      ISANFT.SA[] memory bundle = token.getBundle(tokenId);
      for (uint256 i = 0; i < bundle.length; i++) {
        if (!ISaleData(_get("SaleData")).getSetupById(bundle[i].saleId).isTokenTransferable) {
          revert("SANFT: token not transferable");
        }
      }
    }
  }

  function mintInitialTokens(
    address investor,
    address saleAddress,
    uint256 amount,
    uint256 sellerFee
  ) external override onlyFrom("SaleData") {
    ISANFT token = ISANFT(_get("SANFT"));
    token.mint(investor, saleAddress, uint120(amount), uint120(amount));
    token.mint(apeWallet, saleAddress, uint120(sellerFee), uint120(sellerFee));
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
    ISANFT token = ISANFT(_get("SANFT"));
    address tokenOwner = token.getOwnerOf(tokenIds[0]);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (token.getOwnerOf(tokenIds[i]) != tokenOwner) return (false, "All NFTs must be owned by same owner", 0);
    }
    uint256 counter;
    ISANFT.SA[] memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) return (false, "NFT cannot be merged with itself", 0);
      }
      bundle = token.getBundle(tokenIds[i]);
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

  function merge(uint256[] memory tokenIds) external virtual override {
    ISANFT token = ISANFT(_get("SANFT"));
    require(token.getOwnerOf(tokenIds[0]) == _msgSender(), "SANFTManager: only owners can merge their NFTs");
    (bool isMergeable, string memory message, uint256 counter) = areMergeable(tokenIds);
    require(isMergeable, string(abi.encodePacked("SANFTManager: ", message)));
    ISANFT.SA[] memory bundle;
    uint256 index = 0;
    ISANFT.SA[] memory newBundle = new ISANFT.SA[](counter);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = token.getBundle(tokenIds[i]);
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
      token.burn(tokenIds[i]);
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
      uint256 fee = remainingAmount.mul(feePermillage).div(1000);
      // this is necessary to maintain correct vested percentages
      uint256 catToFullAmount = fullAmount.mul(feePermillage).div(1000);
      bundle[i].fullAmount = uint120(fullAmount.sub(catToFullAmount));
      bundle[i].remainingAmount = uint120(remainingAmount.sub(fee));
      apeBundle[i].fullAmount = uint120(catToFullAmount);
      apeBundle[i].remainingAmount = uint120(fee);
    }
    return (bundle, apeBundle);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) external virtual override onlyFrom("SANFT") {
    ISANFT token = ISANFT(_get("SANFT"));
    require(token.getOwnerOf(tokenId) == _msgSender(), "SANFTManager: only the owner can split an NFT");
    ISANFT.SA[] memory bundle = token.getBundle(tokenId);
    ISANFT.SA[] memory feeBundle;
    (bundle, feeBundle) = _applyFeesToBundle(bundle);
    _createNewToken(apeWallet, feeBundle);
    require(keptAmounts.length == bundle.length, "SANFTManager: length of SAs does not match split");
    uint256 tokenIdA;
    uint256 tokenIdB;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(
        bundle[i].remainingAmount >= keptAmounts[i],
        "SANFTManager: kept amounts cannot be larger that remaining amounts"
      );
      uint120 fullAmountKept = uint120(
        uint256(bundle[i].fullAmount).mul(keptAmounts[i]).div(bundle[i].fullAmount - bundle[i].remainingAmount)
      );
      uint120 otherFullAmount = bundle[i].fullAmount - fullAmountKept;
      if (keptAmounts[i] != 0) {
        tokenIdA = _mintToken(token, tokenIdA, bundle[i].saleId, fullAmountKept, uint120(keptAmounts[i]));
      }
      if (keptAmounts[i] != uint256(bundle[i].remainingAmount)) {
        tokenIdB = _mintToken(
          token,
          tokenIdB,
          bundle[i].saleId,
          otherFullAmount,
          bundle[i].remainingAmount - uint120(keptAmounts[i])
        );
      }
    }
    token.burn(tokenId);
  }

  function _mintToken(
    ISANFT token,
    uint256 tokenId,
    uint16 saleId,
    uint120 fullAmount,
    uint120 amount
  ) internal returns (uint256) {
    if (tokenId == 0) {
      tokenId = token.nextTokenId();
      token.mint(token.getOwnerOf(tokenId), ISaleData(_get("SaleData")).getSaleAddressById(saleId), fullAmount, amount);
    } else {
      ISANFT.SA memory newSA = ISANFT.SA(saleId, fullAmount, amount);
      token.addSAToBundle(tokenId, newSA);
    }
    return tokenId;
  }
}
