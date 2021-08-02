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
    //    console.log("vesting", tokenId);
    // console.log("gas left before vesting", gasleft());
    ISATokenData.SA[] memory bundle = _token.getBundle(tokenId);
    uint256 nextId = _token.nextTokenId();
    bool notEmtpy;
    bool minted;
    for (uint256 i = 0; i < bundle.length; i++) {
      ISATokenData.SA memory sa = bundle[i];
      ISale sale = ISale(sa.sale);
      (uint128 vestedPercentage, uint256 vestedAmount) = sale.vest(_token.ownerOf(tokenId), sa);
      //      console.log("vesting", tokenId, vestedAmount);
      if (vestedPercentage != 100) {
        // we skip vested SAs
        if (!minted) {
          _token.mint(_token.ownerOf(tokenId), sa.sale, vestedAmount, vestedPercentage);
          // console.log("gas left after mint", gasleft());
          minted = true;
        } else {
          ISATokenData.SA memory newSA = ISATokenData.SA(sa.sale, vestedAmount, vestedPercentage);
          _token.addSAToBundle(nextId, newSA);
          // console.log("gas left after addNewSA", gasleft());
        }
        notEmtpy = true;
      }
    }
    _token.burn(tokenId);
    return notEmtpy;
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

  function merge(uint256[] memory tokenIds) external virtual override onlyLevel(MANAGER_LEVEL) {
    uint256 nextId = _token.nextTokenId();
    uint256 counter;
    bool minted;
    // console.log("gas left before merge", gasleft());
    ISATokenData.SA[] memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) {
          revert("SATokenExtras: Bundle can not merge to itself");
        }
      }
      bundle = _token.getBundle(tokenIds[i]);
      bool notEmpty;
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount != 0) {
          notEmpty = true;
          if (!minted) {
            _token.mint(_token.ownerOf(tokenIds[0]), bundle[j].sale, 0, 0);
            minted = true;
          }
          break;
        }
      }
      if (notEmpty) {
        counter++;
      }
    }
    require(counter > 1, "SATokenExtras: Not enough SAs for merging");
    ISATokenData.SA[] memory newBundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.length; j++) {
        if (bundle[j].remainingAmount == 0) {
          // we will skip empty SAs to save storage
          continue;
        }
        bool matched = false;
        newBundle = _token.getBundle(nextId);
        for (uint256 k = 0; k < newBundle.length; k++) {
          if (
            bundle[j].sale == newBundle[k].sale && bundle[j].vestedPercentage == newBundle[k].vestedPercentage
          ) {
            _token.increaseAmountInSA(nextId, k, bundle[j].remainingAmount);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _token.addSAToBundle(nextId, bundle[j]);
        }
      }
      _token.burn(tokenIds[i]);
    }
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override onlyLevel(MANAGER_LEVEL) {
    ISATokenData.SA[] memory bundle = _token.getBundle(tokenId);
    ISATokenData.SA[] memory sas = bundle;
    // console.log("gas left before split", gasleft());
    require(keptAmounts.length == bundle.length, "SANFT: length of sa does not match split");
    bool minted;
    uint256 nextId = _token.nextTokenId();
    uint256 j;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(sas[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
      if (keptAmounts[i] == sas[j].remainingAmount) {
        // no changes
        j++;
        continue;
      }
      if (!minted) {
        _token.mint(
          _token.ownerOf(tokenId),
          sas[i].sale,
          sas[i].remainingAmount.sub(keptAmounts[i]),
          sas[i].vestedPercentage
        );
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
