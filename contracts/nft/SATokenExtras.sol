// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISATokenExtras.sol";
import "../data/ISATokenData.sol";
import "../sale/ISale.sol";
import "../utils/LevelAccess.sol";
import "../utils/IERC20Optimized.sol";
import "../user/IProfile.sol";

import "hardhat/console.sol";

/**
 * @dev External interface of SAToken declared to support ownerOf detection.
 */
interface ISAToken {
  function mint(
    address to,
    address sale,
    uint256 amount,
    uint128 vestedPercentage
  ) external;

  function nextTokenId() external view returns (uint256);

  function burn(uint256 tokenId) external;

  //  function vest(uint256 tokenId) external returns (bool);
  //
  //  function merge(uint256[] memory tokenIds) external;
  //
  //  function split(uint256 tokenId, uint256[] memory keptAmounts) external;

  //  function getTokenExtras() external view returns (address);

  function increaseAmountInSA(
    uint256 bundleId,
    uint256 saIndex,
    uint256 diff
  ) external;

  function getBundle(uint256 tokenId) external view returns (ISATokenData.SA[] memory);

  function ownerOf(uint256 tokenId) external view returns (address owner);

  function addSAToBundle(uint256 bundleId, ISATokenData.SA memory newSA) external;
}

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

  function vest(uint256 tokenId) external virtual override onlyLevel(MANAGER_LEVEL) returns (bool) {
    ISATokenData.SA[] memory bundle = _token.getBundle(tokenId);
    uint256 nextId = _token.nextTokenId();
    bool notEmpty;
    bool minted;
    for (uint256 i = 0; i < bundle.length; i++) {
      ISATokenData.SA memory sa = bundle[i];
      ISale sale = ISale(sa.sale);
      (uint128 vestedPercentage, uint256 vestedAmount) = sale.vest(_token.ownerOf(tokenId), sa);
      if (vestedPercentage > 0 && vestedPercentage < 100) {
        if (!minted) {
          _token.mint(_token.ownerOf(tokenId), sa.sale, vestedAmount, vestedPercentage);
          minted = true;
        } else {
          ISATokenData.SA memory newSA = ISATokenData.SA(sa.sale, vestedAmount, vestedPercentage);
          _token.addSAToBundle(nextId, newSA);
        }
        notEmpty = true;
      }
    }
    if (notEmpty) {
      _token.burn(tokenId);
    }
    return notEmpty;
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
      ISATokenData.SA[] memory bundle = _token.getBundle(tokenId);
      for (uint256 i = 0; i < bundle.length; i++) {
        ISale sale = ISale(bundle[i].sale);
        //          console.log(sale.isTransferable());
        if (!sale.isTransferable()) {
          revert("SAToken: token not transferable");
        }
      }
    }
  }

  function areMergeable(address owner, uint256[] memory tokenIds) external view virtual override returns (string memory) {
    // it returns an error code
    if (tokenIds.length < 2) return "ERROR 1: Cannot merge a single token";
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (_token.ownerOf(tokenIds[i]) != owner) return "ERROR 2: All tokens must be owned by msg.sender";
    }
    uint256 nextId = _token.nextTokenId();
    uint256 counter;
    ISATokenData.SA[] memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) return "ERROR 3: Token cannot be merged with itself";
      }
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount != 0) {
          counter++;
          break;
        }
      }
    }
    if (counter == 1) return "ERROR 4: Not enough not empty tokens";
    ISATokenData.SA[] memory newBundle = _token.getBundle(nextId);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount == 0) {
          continue;
        }
        for (uint256 k = 0; k < newBundle.length; k++) {
          if (bundle[j].sale == newBundle[k].sale) {
            if (bundle[j].vestedPercentage != newBundle[k].vestedPercentage) {
              return "ERROR 5: Inconsistent vested percentages";
            }
            break;
          }
        }
      }
    }
    return "SUCCESS: Tokens are mergeable";
  }

  function merge(address owner, uint256[] memory tokenIds) external virtual override onlyLevel(MANAGER_LEVEL) {
    require(tokenIds.length > 1, "SAToken: are you trying to merge a single token?");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(_token.ownerOf(tokenIds[i]) == owner, "SAToken: Only owner can merge tokens");
    }
    uint256 nextId = _token.nextTokenId();
    uint256 counter;
    // console.log("gas left before merge", gasleft());
    ISATokenData.SA[] memory bundle;
    address firstSale;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) {
          revert("SATokenExtras: Bundle can not merge to itself");
        }
      }
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount != 0) {
          counter++;
          if (firstSale != address(0)) {
            firstSale = bundle[j].sale;
          }
          break;
        }
      }
    }
    require(counter > 1, "SATokenExtras: Not enough SAs for merging");
    uint256 index = 0;
    ISATokenData.SA[] memory newBundle = new ISATokenData.SA[](counter);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount == 0) {
          continue;
        }
        bool matched = false;
        for (uint256 k = 0; k < newBundle.length; k++) {
          if (bundle[j].sale == newBundle[k].sale && bundle[j].vestedPercentage == newBundle[k].vestedPercentage) {
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
    for (uint256 k = 0; k < newBundle.length; k++) {
      //      console.log(newBundle[k].sale, newBundle[k].remainingAmount, newBundle[k].vestedPercentage);
      if (k == 0) {
        _token.mint(owner, newBundle[k].sale, newBundle[k].remainingAmount, newBundle[k].vestedPercentage);
      } else if (newBundle[k].sale != address(0)) {
        _token.addSAToBundle(nextId, newBundle[k]);
      }
    }
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override onlyLevel(MANAGER_LEVEL) {
    ISATokenData.SA[] memory bundle = _token.getBundle(tokenId);
    ISATokenData.SA[] memory sas = bundle;
    // console.log("gas left before split", gasleft());
    require(keptAmounts.length == bundle.length, "SATokenExtras: length of sa does not match split");
    bool minted;
    uint256 nextId = _token.nextTokenId();
    uint256 j;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(sas[i].remainingAmount >= keptAmounts[i], "SATokenExtras: Split is incorrect");
      if (keptAmounts[i] == sas[j].remainingAmount) {
        // no changes
        j++;
        continue;
      }
      if (!minted) {
        _token.mint(_token.ownerOf(tokenId), sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        // console.log("gas left after first mint", gasleft());
        _token.mint(_token.ownerOf(tokenId), sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
        // console.log("gas left after second mint", gasleft());
        minted = true;
      } else {
        ISATokenData.SA memory newSA = ISATokenData.SA(
          sas[i].sale,
          sas[i].remainingAmount.sub(keptAmounts[i]),
          sas[i].vestedPercentage
        );
        _token.addSAToBundle(nextId, newSA);
        // console.log("gas left after adding newSA", gasleft());
        if (keptAmounts[i] != 0) {
          newSA = ISATokenData.SA(sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
          _token.addSAToBundle(nextId + 1, newSA);
          // console.log("gas left after newSA to second token", gasleft());
          j++;
        }
      }
    }
    _token.burn(tokenId);
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
