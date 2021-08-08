// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./ISANFT.sol";
import "./ISANFTManager.sol";
import "../sale/ISale.sol";
import "../registry/RegistryUser.sol";

// for debugging only
//import "hardhat/console.sol";

contract SANFT is ISANFT, RegistryUser, ERC721, ERC721Enumerable {
  using SafeMath for uint256;

  uint256 private _nextTokenId;

  mapping(uint256 => SA[]) internal _bundles;

  constructor(address apeRegistry_) RegistryUser(apeRegistry_) ERC721("SA NFT Token", "SANFT") {}

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://metadata.ape.market/sanft/";
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
    if (from != address(0) && to != address(0)) {
      ISANFTManager(_get("SANFTManager")).beforeTokenTransfer(from, to, tokenId);
    }
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mint(
    address to,
    address saleAddress,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external virtual override onlyFrom("SANFTManager") {
    ISale _sale = ISale(saleAddress);
    uint16 saleId = _sale.saleId();
    require(_bundles[_nextTokenId].length == 0, "SANFT: Bundle already exists");
    _safeMint(to, _nextTokenId);
    SA memory sa = SA(saleId, fullAmount, remainingAmount);
    _bundles[_nextTokenId].push(sa);
    _nextTokenId++;
  }

  function nextTokenId() external view virtual override returns (uint256) {
    return _nextTokenId;
  }

  function withdraw(uint256 tokenId, uint256[] memory amounts) public virtual override {
    ISANFTManager(_get("SANFTManager")).withdraw(tokenId, amounts);
  }

  function burn(uint256 tokenId) external virtual override onlyFrom("SANFTManager") {
    //    console.log("Burning %s", tokenId);
    delete _bundles[tokenId];
    _burn(tokenId);
  }

  function addSAToBundle(uint256 tokenId, SA memory newSA) external override onlyFrom("SANFTManager") {
    _bundles[tokenId].push(newSA);
  }

  function getBundle(uint256 tokenId) external view override returns (SA[] memory) {
    return _bundles[tokenId];
  }

  function getOwnerOf(uint256 tokenId) external view override returns (address) {
    return ownerOf(tokenId);
  }
}
