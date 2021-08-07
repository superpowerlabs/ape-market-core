// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "../utils/IERC20Optimized.sol";
import "../utils/AddressMin.sol";
import "./ISAToken.sol";
import "./ISATokenExtras.sol";
import "../sale/ISale.sol";
import "../registry/ApeRegistryAPI.sol";

// for debugging only
//import "hardhat/console.sol";

contract SAToken is ISAToken, ApeRegistryAPI, ERC721, ERC721Enumerable {
  using SafeMath for uint256;

  uint256 private _nextTokenId;

  address public apeWallet;
  IERC20 private _feeToken;
  uint256 public feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer

  mapping(uint256 => SA[]) internal _bundles;
  ISaleData internal _saleData;

  constructor(
    address apeRegistry_
  )
  ApeRegistryAPI(apeRegistry_)
  ERC721("SA NFT Token", "SANFT") {}

  function setupUpPayments(
    address feeToken,
    uint256 feeAmount_,
    address apeWallet_
  ) external virtual onlyOwner {
    _feeToken = IERC20(feeToken);
    feeAmount = feeAmount_;
    apeWallet = apeWallet_;
  }

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
      ISATokenExtras(_get("SATokenExtras")).beforeTokenTransfer(from, to, tokenId);
    }
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mint(
    address to,
    address sale,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external virtual override {
    address saleAddress = sale;
    //    console.log(saleAddress, 1);
    if (sale == address(0)) {
      require(
        AddressMin.isContract(msg.sender) && ISaleData(_get("SaleData")).getSaleAddressById(msg.sender) > 0,
        "SAToken: Only legit sales can mint its own NFT!"
      );
      saleAddress = msg.sender;
    } else {
      require(msg.sender == _get("SATokenExtras"), "SAToken: Only SATokenExtras can mint tokens for an existing sale");
    }
    ISale _sale = ISale(saleAddress);
    uint16 saleId = _sale.saleId();
    //    console.log(saleAddress, 2);
    _mint(to, saleId, fullAmount, remainingAmount);
  }

  function _mint(
    address to,
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount
  ) internal virtual {
    require(_bundles[_nextTokenId].length == 0, "SAToken: Bundle already exists");
    _safeMint(to, _nextTokenId);
    SA memory sa = SA(saleId, fullAmount, remainingAmount);
    _bundles[_nextTokenId].push(sa);
    //    console.log("Minting %s", _nextTokenId);
    _nextTokenId++;
  }

  function nextTokenId() external view virtual override returns (uint256) {
    return _nextTokenId;
  }

  function withdraw(
    uint256 tokenId,
    uint16 saleId,
    uint256 amount
  ) public virtual override {
    ISATokenExtras(_get("SATokenExtras")).withdraw(tokenId, saleId, amount);
  }

    function burn(uint256 tokenId) external virtual override onlyFrom("SATokenExtras") {
    //    console.log("Burning %s", tokenId);
    delete _bundles[tokenId];
    _burn(tokenId);
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
  }

  function addSAToBundle(uint256 tokenId, SA memory newSA) external override onlyFrom("SATokenExtras") {
    _bundles[tokenId].push(newSA);
  }

  function getBundle(uint256 tokenId) external view override returns (SA[] memory) {
    return _bundles[tokenId];
  }

  function _feeRequired(uint256 tokenId) internal {
    // TODO:
    // this must be granular
    SA memory sa = _bundles[tokenId][0];
    ISale sale = ISale(ISaleData(_get("SaleData")).getSaleAddressById(sa.saleId));
    sale.payFee(msg.sender, feeAmount);
  }

  function areMergeable(uint256[] memory tokenIds) public view override returns (bool, string memory) {
    (bool isMergeable, string memory message,) = ISATokenExtras(_get("SATokenExtras")).areMergeable(msg.sender, tokenIds);
    return (isMergeable, message);
  }

  function merge(uint256[] memory tokenIds) external virtual override {
    // The APE dApp should check areMergeable before calling a merge, to avoid the risk that the user consumes gas for nothing.
    // It should also verify that the user has approved the token as a operator for the paymentToken
    ISATokenExtras(_get("SATokenExtras")).merge(msg.sender, tokenIds);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Only owner can split a token");
    //    _feeRequired(tokenId);
    ISATokenExtras(_get("SATokenExtras")).split(tokenId, keptAmounts);
  }

  function getOwnerOf(uint256 tokenId) external view override returns (address) {
    return ownerOf(tokenId);
  }
}
