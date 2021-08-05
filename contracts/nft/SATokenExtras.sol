// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import "./ISATokenExtras.sol";
import "./ISAToken.sol";
import "../sale/ISale.sol";
import "../utils/LevelAccess.sol";
import "../utils/IERC20Optimized.sol";
import "../user/IProfile.sol";

import "hardhat/console.sol";

contract SATokenExtras is ISATokenExtras, LevelAccess {
  using SafeMath for uint256;

  uint256 public constant MANAGER_LEVEL = 1;

  ISAToken private _token;
  ISale private _sale;
  IProfile public profile;

  modifier onlySAToken() {
    require(msg.sender == address(_token), "SATokenExtras: caller is not the SA NFT token");
    _;
  }

  constructor(address profileAddress) {
    profile = IProfile(profileAddress);
  }

  function withdraw(
    uint256 tokenId,
    uint16 saleId,
    uint256 amount
  ) external virtual override onlyLevel(MANAGER_LEVEL) {
    ISAToken.SA[] memory sas = _token.getBundle(tokenId);
    bool done;
    for (uint256 i = 0; i < sas.length; i++) {
      if (saleId != sas[i].saleId) {
        continue;
      }
      ISale sale = ISale(_token.saleData().getSaleAddressById(sas[i].saleId));
      done = sale.vest(_token.getOwnerOf(tokenId), sas[i].fullAmount, sas[i].remainingAmount, amount);
      if (done) {
        sas[i].remainingAmount = uint120(uint256(sas[i].remainingAmount).sub(amount));
      }
      break;
    }
    if (done) {
      // move SA to new NFT and burns the current one
      _createNewToken(_token.getOwnerOf(tokenId), sas);
      _token.burn(tokenId);
    }
  }

  function _createNewToken(address owner, ISAToken.SA[] memory sas) internal {
    uint256 nextId = _token.nextTokenId();
    bool minted;
    for (uint256 i = 0; i < sas.length; i++) {
      if (sas[i].remainingAmount > 0) {
        if (!minted) {
          _token.mint(owner, _token.saleData().getSaleAddressById(sas[i].saleId), sas[i].fullAmount, sas[i].remainingAmount);
          minted = true;
        } else {
          //          ISAToken.SA memory newSA = ISAToken.SA(sas[i].saleId, sas[i].fullAmount, sas[i].remainingAmount);
          _token.addSAToBundle(nextId, ISAToken.SA(sas[i].saleId, sas[i].fullAmount, sas[i].remainingAmount));
        }
      }
    }
  }

  function setToken(address tokenAddress) external onlyLevel(OWNER_LEVEL) {
    require(isContract(tokenAddress), "SATokenExtras: token is not a contract");
    _token = ISAToken(tokenAddress);
    grantLevel(MANAGER_LEVEL, tokenAddress);
  }

  function grantLevel(uint256 level, address addr) public virtual override onlyLevel(OWNER_LEVEL) {
    if (level == MANAGER_LEVEL) {
      require(addr == address(_token), "SATokenExtras: only SAToken can manage me");
    }
    super.grantLevel(level, addr);
  }

  function beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external view override onlyLevel(OWNER_LEVEL) {
    if (!profile.areAccountsAssociated(from, to)) {
      // check if any sale is not transferable
      ISAToken.SA[] memory bundle = _token.getBundle(tokenId);
      for (uint256 i = 0; i < bundle.length; i++) {
        if (!_token.saleData().getSetupById(bundle[i].saleId).isTokenTransferable) {
          revert("SAToken: token not transferable");
        }
      }
    }
  }

  function areMergeable(address tokenOwner, uint256[] memory tokenIds)
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
    if (tokenIds.length < 2) return (false, "Cannot merge a single token", 0);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (_token.getOwnerOf(tokenIds[i]) != tokenOwner) return (false, "All tokens must be owned by msg.sender", 0);
    }
    uint256 counter;
    ISAToken.SA[] memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) return (false, "Token cannot be merged with itself", 0);
      }
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount != 0) {
          counter++;
          break;
        }
      }
    }
    if (counter == 1) return (false, "Not enough not empty SAs", 0);
    return (true, "Tokens are mergeable", counter);
  }

  function merge(address tokenOwner, uint256[] memory tokenIds) external virtual override onlyLevel(MANAGER_LEVEL) {
    (bool isMergeable, string memory message, uint256 counter) = areMergeable(tokenOwner, tokenIds);
    require(isMergeable, message);
    ISAToken.SA[] memory bundle;
    uint256 index = 0;
    ISAToken.SA[] memory newBundle = new ISAToken.SA[](counter);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _token.getBundle(tokenIds[i]);
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
      _token.burn(tokenIds[i]);
    }
    // TODO pay the fees
    _createNewToken(tokenOwner, newBundle);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override onlyLevel(MANAGER_LEVEL) {
    ISAToken.SA[] memory bundle = _token.getBundle(tokenId);
    ISAToken.SA[] memory sas = bundle;
    require(keptAmounts.length == bundle.length, "SATokenExtras: length of sa does not match split");
    uint256 tokenIdA;
    uint256 tokenIdB;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(sas[i].remainingAmount >= keptAmounts[i], "SATokenExtras: Split is incorrect");
      uint120 fullAmountKept = uint120(
        uint256(sas[i].fullAmount).mul(keptAmounts[i]).div(sas[i].fullAmount - sas[i].remainingAmount)
      );
      uint120 otherFullAmount = sas[i].fullAmount - fullAmountKept;
      if (keptAmounts[i] != 0) {
        tokenIdA = _mintToken(tokenIdA, sas[i].saleId, fullAmountKept, uint120(keptAmounts[i]));
      }
      if (keptAmounts[i] != uint256(sas[i].remainingAmount)) {
        tokenIdB = _mintToken(tokenIdB, sas[i].saleId, otherFullAmount, sas[i].remainingAmount - uint120(keptAmounts[i]));
      }
    }
    _token.burn(tokenId);
  }

  function _mintToken(uint tokenId, uint16 saleId, uint120 fullAmount,uint120 amount) internal returns (uint) {
    if (tokenId == 0) {
      tokenId = _token.nextTokenId();
      _token.mint(_token.getOwnerOf(tokenId), _token.saleData().getSaleAddressById(saleId), fullAmount, amount);
    } else {
      ISAToken.SA memory newSA = ISAToken.SA(saleId, fullAmount, amount);
      _token.addSAToBundle(tokenId, newSA);
    }
    return tokenId;
  }

  // from OpenZeppelin's Address.sol
  function isContract(address account) public view override returns (bool) {
    uint256 size;
    // solium-disable-next-line security/no-inline-assembly
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }
}
