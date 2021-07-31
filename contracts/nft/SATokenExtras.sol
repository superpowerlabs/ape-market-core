// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ISATokenExtended.sol";
import "./ISATokenExtras.sol";
import "./ISAStorage.sol";
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

  modifier onlySAToken {
    require(msg.sender == address(_token), "SATokenExtras: caller is not the SA NFT token");
    _;
  }

  constructor(address profileAddress) {
    profile = IProfile(profileAddress);
  }

  function _getPrimarySaleFeeToken(uint256 tokenId) internal view virtual
  returns (address) {
    ISAStorage.Bundle memory bundle = _token.getBundle(tokenId);
    ISale sale = ISale(bundle.sas[0].sale);
    return sale.getPaymentToken();
  }

  function vest(uint256 tokenId) external virtual override
  onlyLevel(MANAGER_LEVEL) returns (bool) {
    //    console.log("vesting", tokenId);
    // console.log("gas left before vesting", gasleft());
    ISAStorage.Bundle memory bundle = _token.getBundle(tokenId);
    uint256 nextId = _token.nextTokenId();
    bool notEmtpy;
    bool minted;
    for (uint256 i = 0; i < bundle.sas.length; i++) {
      ISAStorage.SA memory sa = bundle.sas[i];
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
          ISAStorage.SA memory newSA = ISAStorage.SA(sa.sale, vestedAmount, vestedPercentage);
          _token.addSAToBundle(nextId, newSA);
          // console.log("gas left after addNewSA", gasleft());
        }
        notEmtpy = true;
      }
    }
    _token.burn(tokenId);
    return notEmtpy;
  }

  function setToken(address tokenAddress) external
  onlyLevel(OWNER_LEVEL) {
    require(isContract(tokenAddress), "SATokenExtras: token is not a contract");
    _token = ISAToken(tokenAddress);
    grantLevel(MANAGER_LEVEL, tokenAddress);
  }

  function grantLevel(uint256 level, address addr) public virtual override
  onlyLevel(OWNER_LEVEL) {
    if (level == MANAGER_LEVEL) {
      require(addr == address(_token), "SATokenExtras: only SAToken can manage me");
    }
    super.grantLevel(level, addr);
  }

  function beforeTokenTransfer(address from, address to, uint256 tokenId) external view override
  onlyLevel(OWNER_LEVEL) {
    if (!profile.areAccountsAssociated(from, to)) {
      // check if any sale is not transferable
      ISAStorage.Bundle memory bundle = _token.getBundle(tokenId);
      for (uint256 i = 0; i < bundle.sas.length; i++) {
        ISale sale = ISale(bundle.sas[i].sale);
        //          console.log(sale.isTransferable());
        if (!sale.isTransferable()) {
          revert("SAToken: token not transferable");
        }
      }
    }
  }

  function merge(uint256[] memory tokenIds) external virtual override
  onlyLevel(MANAGER_LEVEL) {
    uint256 nextId = _token.nextTokenId();
    uint256 counter;
    bool minted;
    // console.log("gas left before merge", gasleft());
    ISAStorage.Bundle memory bundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      for (uint256 w = 0; w < tokenIds.length; w++) {
        if (w != i && tokenIds[w] == tokenIds[i]) {
          revert("SATokenExtras: Bundle can not merge to itself");
        }
      }
      bundle = _token.getBundle(tokenIds[i]);
      bool notEmpty;
      for (uint256 j = 0; j < bundle.sas.length; j++) {
        if (bundle.sas[j].remainingAmount != 0) {
          notEmpty = true;
          if (!minted) {
            _token.mint(_token.ownerOf(tokenIds[0]), bundle.sas[j].sale, 0, 0);
            // console.log("gas left after mint", gasleft());
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
    ISAStorage.Bundle memory newBundle;
    for (uint256 i = 0; i < tokenIds.length; i++) {
      bundle = _token.getBundle(tokenIds[i]);
      for (uint256 j = 0; j < bundle.sas.length; j++) {
        if (bundle.sas[j].remainingAmount == 0) {
          // we will skip empty SAs to save storage
          continue;
        }
        bool matched = false;
        newBundle = _token.getBundle(nextId);
        for (uint256 k = 0; k < newBundle.sas.length; k++) {
          if (bundle.sas[j].sale == newBundle.sas[k].sale &&
            bundle.sas[j].vestedPercentage == newBundle.sas[k].vestedPercentage) {
            _token.increaseAmountInSA(nextId, k, bundle.sas[j].remainingAmount);
            // console.log("gas left after increase to SA", gasleft());
            matched = true;
            break;
          }
        }
        if (!matched) {
          _token.addSAToBundle(nextId, bundle.sas[j]);
          // console.log("gas left after adding new SA", gasleft());
        }
      }
      _token.burn(tokenIds[i]);
    }
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override
  onlyLevel(MANAGER_LEVEL) {
    ISAStorage.Bundle memory bundle = _token.getBundle(tokenId);
    ISAStorage.SA[] memory sas = bundle.sas;
    // console.log("gas left before split", gasleft());
    require(keptAmounts.length == bundle.sas.length, "SANFT: length of sa does not match split");
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
        _token.mint(_token.ownerOf(tokenId), sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        // console.log("gas left after first mint", gasleft());
        _token.mint(_token.ownerOf(tokenId), sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
        // console.log("gas left after second mint", gasleft());
        minted = true;
      } else {
        ISAStorage.SA memory newSA = ISAStorage.SA(sas[i].sale, sas[i].remainingAmount.sub(keptAmounts[i]), sas[i].vestedPercentage);
        _token.addSAToBundle(nextId, newSA);
        // console.log("gas left after adding newSA", gasleft());
        if (keptAmounts[i] != 0) {
          newSA = ISAStorage.SA(sas[i].sale, keptAmounts[i], sas[i].vestedPercentage);
          _token.addSAToBundle(nextId + 1, newSA);
          // console.log("gas left after newSA to second token", gasleft());
          j++;
        }
      }
    }
    _token.burn(tokenId);
  }


  // from OpenZeppelin's Address.sol
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // solium-disable-next-line security/no-inline-assembly
    assembly {size := extcodesize(account)}
    return size > 0;
  }

}
