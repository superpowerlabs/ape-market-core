// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISAToken.sol";
import "./ISAStorage.sol";

contract SAManager {

  // TODO: to be completed soon

//  modifier feeRequired() {
//    //
//    _;
//  }
//
//  function merge(uint256[] memory tokenIds) external virtual feeRequired {
//    require(tokenIds.length >= 2, "SANFT: Too few SAs for merging");
//    for (uint256 i = 0; i < tokenIds.length; i++) {
//      require(ownerOf(tokenIds[i]) == msg.sender, "SANFT: Only owner can merge bundle");
//    }
//    if (!vest(tokenIds[0])) {
//      return;
//    }
//
//    ISAStorage.Bundle storage bundle0 = _bundles[tokenIds[0]];
//    // keep this in a variable since sa0.sas will change
//    uint256 bundle0Len = bundle0.sas.length;
//    for (uint256 i = 1; i < tokenIds.length; i++) {
//      require(tokenIds[0] != tokenIds[i], "SANFT: Bundle can not merge to itself");
//      if (!vest(tokenIds[i])) {
//        continue;
//      }
//      ISAStorage.Bundle storage bundle1 = _bundles[tokenIds[i]];
//      // go through each sa in bundle1, and compare with every sa
//      // in bundle0, if same sale then combine and update the matching sa, otherwise, push
//      // into bundle0.
//      for (uint256 j = 0; j < bundle1.sas.length; j++) {
//        bool matched = false;
//        for (uint256 k = 0; k < bundle0Len; k++) {
//          if (bundle1.sas[j].sale == bundle0.sas[k].sale) {
//            bundle0.sas[k].remainingAmount = bundle0.sas[k].remainingAmount.add(bundle1.sas[j].remainingAmount);
//            matched = true;
//            break;
//          }
//        }
//        if (!matched) {
//          bundle0.sas.push(bundle1.sas[j]);
//        }
//      }
//      _burn(tokenIds[i]);
//    }
//  }
//
//  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual onlyNFTOwner(tokenId) feeRequired {
//    if (!vest(tokenId)) {
//      return;
//    }
//    ISAStorage.Bundle storage bundle = _bundles[tokenId];
//    ISAStorage.SA[] storage sas = bundle.sas;
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
////    cleanEmptySAs(bundle, tokenId, numEmptySAs);
//  }

}
