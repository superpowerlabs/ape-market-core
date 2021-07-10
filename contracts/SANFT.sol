pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Sale.sol";
import "./Ape.sol";

contract SANFT is ERC721Enumerable {
  modifier onlyApeAdmin() {
    require(_apeAdmin == msg.sender, "SANFT:Caller is not ape admin");
    _;
  }

  modifier onlyNFTOwner(uint256 saId) {
    require(ownerOf(saId) == msg.sender, "SANFT:Caller is not NFT owner");
    _;
  }

  modifier feeRequired() {
    _feeToken.transferFrom(msg.sender, _apeAdmin, _feeAmount);
    _;
  }

  using SafeMath for uint256;
  address _apeAdmin;
  ERC20 _feeToken;
  uint256 _feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer

  struct SubSA {
    address sale;
    uint256 remainingAmount;
    uint256 vestedPercentage;
  }

  struct SA {
    SubSA[] subSAs;
    uint256 creationTime; // when the SA is create = when it was first invested
    uint256 acquisitionTime; // == creation for first owner. == transfer time for later owners
  }

  uint256 private _nextTokenId = 1; // will be incremented after  use. 0 reserved for invalid sa

  mapping(uint256 => SA) _sas; // TODO: delete _sas[burned id] to save gas?

  constructor(address feeToken, uint256 feeAmount) ERC721("SA NFT Token", "SANFT") {
    _apeAdmin = msg.sender;
    _feeToken = ERC20(feeToken);
    _feeAmount = feeAmount;
  }

  function getSA(uint saId) public virtual view returns (SA memory) {
    return _sas[saId];
  }

  function _transfer(address from, address to, uint256 tokenId) internal virtual override feeRequired {
    super._transfer(from, to, tokenId);
    _sas[tokenId].acquisitionTime = block.timestamp;
  }

  // remove subSAs that had no token left.  The containing SA will also be burned if all of
  // its sub SAs are empty and function returns false.
  function cleanEmptySA(SA storage sa, uint256 saId, uint256 numEmptySubSAs) internal virtual returns(bool) {
    bool emptySA = false;
    if (sa.subSAs.length  == 0 || sa.subSAs.length == numEmptySubSAs) {
      console.log("SANFT: Simple empty SA", saId, sa.subSAs.length, numEmptySubSAs);
      emptySA = true;
    } else {
      console.log("SANFT: Regular process");
      if (numEmptySubSAs < sa.subSAs.length/2) { // empty is less than half, then shift elements
        console.log("SANFT: Taking the shift route", sa.subSAs.length, numEmptySubSAs);
        for (uint256 i = 0; i < sa.subSAs.length; i++) {
          if (sa.subSAs[i].remainingAmount == 0) {
            // find one subSA from the end that's not 100% vested
            for(uint256 j = sa.subSAs.length - 1; j > i; j--) {
              if(sa.subSAs[j].remainingAmount > 0) {
                sa.subSAs[i] = sa.subSAs[j];
              }
              sa.subSAs.pop();
            }
            // cannot find such subSA
            if (sa.subSAs[i].remainingAmount == 0) {
              assert(sa.subSAs.length -1 == i);
              sa.subSAs.pop();
            }
          }
        }
      } else { // empty is more than half, then create a new array
        console.log("Taking the new array route", sa.subSAs.length, numEmptySubSAs);
        SubSA[] memory newSubSAs = new SubSA[](sa.subSAs.length - numEmptySubSAs);
        uint256 subSAindex;
        for (uint256 i = 0; i < sa.subSAs.length; i++) {
          if (sa.subSAs[i].remainingAmount > 0) {
            newSubSAs[subSAindex++] = sa.subSAs[i];
          }
          delete sa.subSAs[i];
        }
        delete sa.subSAs;
        assert (sa.subSAs.length == 0);
        for (uint256 i = 0; i < newSubSAs.length; i++) {
          sa.subSAs.push(newSubSAs[i]);
        }
      }
    }
    if (emptySA || sa.subSAs.length == 0) {
      _burn(saId);
      delete _sas[saId].subSAs;
      delete _sas[saId];
      return false;
    }
    return true;
  }

  function merge(uint256[] memory saIds) external virtual feeRequired {
    require(saIds.length >= 2, "SANFT: Too few SAs for merging");
    for (uint256 i = 0; i < saIds.length; i++) {
      require(ownerOf(saIds[i]) == msg.sender, "SANFT: Only owner can merge sa");
    }
    if (!vest(saIds[0])) {
      return;
    }

    SA storage sa0 = _sas[saIds[0]];
    // keep this in a variable since sa0.subSAs will change
    uint256 sa0Len = sa0.subSAs.length;
    for (uint256 i = 1; i < saIds.length; i++) {
      require(saIds[0] != saIds[i], "SANFT: SA can not merge to itself");
      if (!vest(saIds[i])) {
        continue;
      }
      SA storage sa1 = _sas[saIds[i]];
      // go through each sub sa in sa1, and compare with every sub sa
      // in sa0, if same sale then combine and update the matching sub sa, otherwise, push
      // into sa0.
      for (uint256 j = 0; j < sa1.subSAs.length; j++) {
        bool matched = false;
        for (uint256 k = 0; k < sa0Len; k++) {
          if (sa1.subSAs[j].sale == sa0.subSAs[k].sale) {
            sa0.subSAs[k].remainingAmount = sa0.subSAs[k].remainingAmount.add(sa1.subSAs[j].remainingAmount);
            matched = true;
            break;
          }
        }
        if (!matched) {
          sa0.subSAs.push(sa1.subSAs[j]);
        }
      }
      _burn(saIds[i]);
    }
  }

  function split(uint256 saId, uint256[] memory keptAmounts) public virtual onlyNFTOwner(saId) feeRequired {
    if (!vest(saId)) {
      return;
    }
    SA storage sa = _sas[saId];
    SubSA[] storage subSAs = sa.subSAs;

    require(keptAmounts.length == sa.subSAs.length, "SANFT: length of subSA does not match split");
    uint256 numEmptySubSAs;
    for (uint256 i = 0; i < keptAmounts.length; i++) {
      require(subSAs[i].remainingAmount >= keptAmounts[i], "SANFT: Split is incorrect");
      if (keptAmounts[i] == 0) {
        numEmptySubSAs++;
      }
      uint256 newSubSAAmount = subSAs[i].remainingAmount - keptAmounts[i];
      if(newSubSAAmount > 0) {
        SA storage newSA = _sas[_nextTokenId];
        SubSA memory newSubSA = SubSA(subSAs[i].sale, subSAs[i].remainingAmount - keptAmounts[i], 0);
        newSA.subSAs.push(newSubSA);
      }
      subSAs[i].remainingAmount = keptAmounts[i];
    }
    if (_sas[_nextTokenId].subSAs.length > 0) {
      _sas[_nextTokenId].creationTime = block.timestamp;
      _sas[_nextTokenId].acquisitionTime = block.timestamp;
      _mint(msg.sender, _nextTokenId++);
    }
    cleanEmptySA(sa, saId, numEmptySubSAs);
  }


  // vest return the number of non empty subSAs after vest.
  // if there is no non-empty subSAs, then SA will burned
  function vest(uint256 saId) public virtual onlyNFTOwner(saId) returns(bool) {
    console.log("vesting", saId);
    SA storage sa = _sas[saId];
    uint256 numEmptySubSAs = 0;
    for (uint256 i = 0; i < sa.subSAs.length; i++) {
      SubSA storage subSA = sa.subSAs[i];
      Sale sale = Sale(subSA.sale);
      uint256 vestedPercentage = sale.getVestedPercentage();
      uint256 vestedAmount = sale.getVestedAmount(vestedPercentage, subSA.vestedPercentage, subSA.remainingAmount);
      sale.vest(ownerOf(saId), vestedAmount);
      console.log("vesting", saId, vestedAmount);
      if (vestedPercentage == 100) {
        numEmptySubSAs++;
      }
      // reprocess current element in next round;
      subSA.remainingAmount = subSA.remainingAmount.sub(vestedAmount);
      subSA.vestedPercentage = vestedPercentage;
    }
    return cleanEmptySA(sa, saId, numEmptySubSAs);
  }

  function mint(address to, Sale sale_, uint256 amount) external virtual {
    // note no one else should be able to call this, not even
    // admin or sale owner
    require(address(sale_) == msg.sender, "SANFT: Only sale contract can mint its own NFT!");
    _mint(to, _nextTokenId);
    console.log("Minted NFT", _nextTokenId, address(to), amount);
    SubSA memory simple = SubSA({sale : address(sale_), remainingAmount : amount, vestedPercentage : 0});
    SA storage sa = _sas[_nextTokenId];
    sa.acquisitionTime = block.timestamp;
    sa.creationTime = block.timestamp;
    sa.subSAs.push(simple);
    _nextTokenId ++;
  }

  function _burn(uint256 SAId) internal virtual override{
    super._burn(SAId);
    delete _sas[SAId];
  }
}
