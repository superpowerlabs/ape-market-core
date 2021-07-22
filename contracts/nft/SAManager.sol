// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ISAStorage.sol";
import "../sale/ISale.sol";
import "../utils/LevelAccess.sol";

interface ISATokenOptimized {

  function pause(uint tokenId) external;

  function unpause(uint tokenId) external;

  function pauseBatch(uint[] memory tokenIds) external;

  function unpauseBatch(uint[] memory tokenIds) external;

  function isPaused(uint tokenId) external view returns (bool);

  function updateFactory(address factoryAddress) external;

  function updateStorage(address storageAddress) external;

  function factory() external view returns (address);

  function mint(address to, uint256 amount) external;

  function burn(uint256 tokenId) external;

  function ownerOf(uint tokenId) external view returns (address);

  function vest(uint256 tokenId) external returns (bool);

}

contract SAManager is LevelAccess {

  using SafeMath for uint256;

  ISATokenOptimized private _token;
  ISAStorage private _storage;
  ISale private _sale;
  address private _apeWallet;

  // TODO: must manage this dynamically
  uint private _feeAmount = 1;

  modifier feeRequired(uint tokenId) {
    // TODO: should we transfer instead from the user's SAs to the Ape's SAs?
    // Is the feetoken the same for any sale? It may not be, right?
    // Does the user pay with the feeToken used in the primary sale, i.e., sas[0]?
    address paymentToken = _getPrimarySaleFeeToken(tokenId);
    IERC20(paymentToken).transferFrom(msg.sender, _apeWallet, _feeAmount);
    _;
  }

  function _getPrimarySaleFeeToken(uint tokenId) internal view virtual
  returns (address) {
    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    ISale sale = ISale(bundle.sas[0].sale);
    return sale.getPaymentToken();
  }

  constructor(address tokenAddress, address storageAddress){
    _token = ISATokenOptimized(tokenAddress);
    _storage = ISAStorage(storageAddress);
  }

  function updateToken(address newTokenAddress) external
  onlyLevel(OWNER_LEVEL) {
    _token = ISATokenOptimized(newTokenAddress);
  }

  function setApeWallet(address apeWallet_) external
  onlyLevel(OWNER_LEVEL) {
    _apeWallet = apeWallet_;
  }

  function apeWallet() external view
  returns (address) {
    return _apeWallet;
  }

  function merge(uint256[] memory tokenIds, bool vestTokensBefore) external virtual
  // TODO: lets assume for now that they pay with the feetoken used in the primary SA
  // we must decide how to handle these cases
  feeRequired(tokenIds[0]) {
    require(tokenIds.length >= 2, "SAManager: Not enough SAs for merging");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(_token.ownerOf(tokenIds[i]) == msg.sender, "SAManager: Only owner can merge tokens");
    }
    if (vestTokensBefore && !_token.vest(tokenIds[0])) {
      return;
    }

    ISAStorage.Bundle memory bundle0 = _storage.getBundle(tokenIds[0]);
    // keep this in a variable since sa0.sas will change
    uint256 bundle0Len = bundle0.sas.length;
    for (uint256 i = 1; i < tokenIds.length; i++) {
      require(tokenIds[0] != tokenIds[i], "SAManager: Bundle can not merge to itself");
      if (vestTokensBefore && !_token.vest(tokenIds[i])) {
        continue;
      }
      ISAStorage.Bundle memory bundle1 = _storage.getBundle(tokenIds[i]);
      // go through each sa in bundle1, and compare with every sa
      // in bundle0, if same sale then combine and update the matching sa, otherwise, push
      // into bundle0.
      for (uint256 j = 0; j < bundle1.sas.length; j++) {
        bool matched = false;
        for (uint256 k = 0; k < bundle0Len; k++) {
          if (bundle1.sas[j].sale == bundle0.sas[k].sale) {
            _storage.changeSA(tokenIds[j], k, bundle1.sas[j].remainingAmount, true);
            _storage.popSA(tokenIds[j]);
            matched = true;
            break;
          }
        }
        if (!matched) {
          _storage.addNewSA(tokenIds[0], bundle1.sas[j]);
        }
      }
      _token.burn(tokenIds[i]);
    }
  }

//  function split(uint256 tokenId, uint256[] memory keptAmounts, bool vestTokensBefore) public virtual feeRequired {
//
//    require(_token.ownerOf(tokenIds[i]) == msg.sender, "SAManager: Only owner can split a token");
//
//    if (vestTokensBefore && !_token.vest(tokenId)) {
//      return;
//    }
//    ISAStorage.Bundle memory bundle = _bundles[tokenId];
//    ISAStorage.SA[] memory sas = bundle.sas;
//
//    require(keptAmounts.length == bundle.sas.length, "SANFT: length of sa does not match split");
//    uint256 numEmptySAs;
//    for (uint256 i = 0; i < keptAmounts.length; i++) {
//      require(sas[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
//      if (keptAmounts[i] == 0) {
//        numEmptySAs++;
//      }
//      uint256 newSAAmount = sas[i].remainingAmount - keptAmounts[i];
//      if(newSAAmount > 0) {
//        ISAStorage.Bundle storage newBundle = _bundles[_nextTokenId];
//        ISAStorage.SA memory newSA = SA(sas[i].sale, sas[i].remainingAmount - keptAmounts[i], 0);
//        newBundle.sas.push(newSA);
//      }
//      sas[i].remainingAmount = keptAmounts[i];
//    }
//    if (_bundles[_nextTokenId].sas.length > 0) {
//      _bundles[_nextTokenId].creationTime = block.timestamp;
//      _bundles[_nextTokenId].acquisitionTime = block.timestamp;
//      _mint(msg.sender, _nextTokenId++);
//    }
//  }

  // remove subSAs that had no token left.  The containing SA will also be burned if all of
  // its sub SAs are empty and function returns false.
//  function cleanEmptySA(SA storage sa, uint256 saId, uint256 numEmptySubSAs) internal virtual returns(bool) {
//    bool emptySA = false;
//    if (sa.subSAs.length == 0 || sa.subSAs.length == numEmptySubSAs) {
//      console.log("SANFT: Simple empty SA", saId, sa.subSAs.length, numEmptySubSAs);
//      emptySA = true;
//    } else {
//      console.log("SANFT: Regular process");
//      if (numEmptySubSAs < sa.subSAs.length/2) { // empty is less than half, then shift elements
//        console.log("SANFT: Taking the shift route", sa.subSAs.length, numEmptySubSAs);
//        for (uint256 i = 0; i < sa.subSAs.length; i++) {
//          if (sa.subSAs[i].remainingAmount == 0) {
//            // find one subSA from the end that's not 100% vested
//            for(uint256 j = sa.subSAs.length - 1; j > i; j--) {
//              if(sa.subSAs[j].remainingAmount > 0) {
//                sa.subSAs[i] = sa.subSAs[j];
//              }
//              sa.subSAs.pop();
//            }
//            // cannot find such subSA
//            if (sa.subSAs[i].remainingAmount == 0) {
//              assert(sa.subSAs.length - 1 == i);
//              sa.subSAs.pop();
//            }
//          }
//        }
//      } else { // empty is more than half, then create a new array
//        console.log("Taking the new array route", sa.subSAs.length, numEmptySubSAs);
//        SubSA[] memory newSubSAs = new SubSA[](sa.subSAs.length - numEmptySubSAs);
//        uint256 subSAindex;
//        for (uint256 i = 0; i < sa.subSAs.length; i++) {
//          if (sa.subSAs[i].remainingAmount > 0) {
//            newSubSAs[subSAindex++] = sa.subSAs[i];
//          }
//          delete sa.subSAs[i];
//        }
//        delete sa.subSAs;
//        assert (sa.subSAs.length == 0);
//        for (uint256 i = 0; i < newSubSAs.length; i++) {
//          sa.subSAs.push(newSubSAs[i]);
//        }
//      }
//    }
//    if (emptySA || sa.subSAs.length == 0) {
//      _burn(saId);
//      delete _sas[saId].subSAs;
//      delete _sas[saId];
//      return false;
//    }
//    return true;
//  }

}
