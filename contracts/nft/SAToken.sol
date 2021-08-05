// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "../utils/IERC20Optimized.sol";
import "../utils/LevelAccess.sol";
import "./ISAToken.sol";
import "./ISATokenExtras.sol";
import "../sale/ISale.sol";
import "../sale/ISaleFactory.sol";

// for debugging only
//import "hardhat/console.sol";

contract SAToken is ISAToken, ERC721, ERC721Enumerable, LevelAccess {
  using SafeMath for uint256;

  uint256 public constant MANAGER_LEVEL = 1;
  uint256 private _nextTokenId;

  ISaleFactory public factory;
  ISATokenExtras private _extras;

  address public apeWallet;
  IERC20 private _feeToken;
  uint256 public feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer

  mapping(uint256 => SA[]) internal _bundles;
  ISaleData internal _saleData;

  constructor(
    address saleData_,
    address factoryAddress,
    address extrasAddress
  ) ERC721("SA NFT Token", "SANFT") {
    _saleData = ISaleData(saleData_);
    factory = ISaleFactory(factoryAddress);
    _extras = ISATokenExtras(extrasAddress);
    grantLevel(MANAGER_LEVEL, extrasAddress);
  }

  function saleData() external view override returns (ISaleData) {
    return _saleData;
  }

  function getTokenExtras() external view override returns (address) {
    return address(_extras);
  }

  function updateFactory(address factoryAddress) external virtual onlyLevel(OWNER_LEVEL) {
    factory = ISaleFactory(factoryAddress);
  }

  function setupUpPayments(
    address feeToken,
    uint256 feeAmount_,
    address apeWallet_
  ) external virtual onlyLevel(OWNER_LEVEL) {
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
      _extras.beforeTokenTransfer(from, to, tokenId);
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
        _extras.isContract(msg.sender) && _saleData.isLegitSale(msg.sender),
        "SAToken: Only legit sales can mint its own NFT!"
      );
      saleAddress = msg.sender;
    } else {
      require(levels[msg.sender] == MANAGER_LEVEL, "SAToken: Only SATokenExtras can mint tokens for an existing sale");
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
    _extras.withdraw(tokenId, saleId, amount);
  }

  function burn(uint256 tokenId) external virtual override onlyLevel(MANAGER_LEVEL) {
    //    console.log("Burning %s", tokenId);
    delete _bundles[tokenId];
    _burn(tokenId);
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
  }

  function addSAToBundle(uint256 tokenId, SA memory newSA) external override onlyLevel(MANAGER_LEVEL) {
    _bundles[tokenId].push(newSA);
  }

  function getBundle(uint256 tokenId) external view override returns (SA[] memory) {
    return _bundles[tokenId];
  }

  function increaseAmountInSA(
    uint256 tokenId,
    uint256 saIndex,
    uint256 diff
  ) external override onlyLevel(MANAGER_LEVEL) {
    SA memory sa = _bundles[tokenId][saIndex];
    sa.remainingAmount = uint120(uint256(sa.remainingAmount).add(diff));
    sa.fullAmount = uint120(uint256(sa.fullAmount).add(diff));
    _bundles[tokenId][saIndex] = sa;
  }

  function _feeRequired(uint256 tokenId) internal {
    // TODO:
    // this must be granular
    SA memory sa = _bundles[tokenId][0];
    ISale sale = ISale(_saleData.getSaleAddressById(sa.saleId));
    sale.payFee(msg.sender, feeAmount);
  }

  function areMergeable(uint256[] memory tokenIds) public view override returns (bool, string memory) {
    (bool isMergeable, string memory message, ) = _extras.areMergeable(msg.sender, tokenIds);
    return (isMergeable, message);
  }

  function merge(uint256[] memory tokenIds) external virtual override {
    // The APE dApp should check areMergeable before calling a merge, to avoid the risk that the user consumes gas for nothing.
    // It should also verify that the user has approved the token as a operator for the paymentToken
    _extras.merge(msg.sender, tokenIds);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Only owner can split a token");
    //    _feeRequired(tokenId);
    _extras.split(tokenId, keptAmounts);
  }

  function getOwnerOf(uint256 tokenId) external view override returns (address) {
    return ownerOf(tokenId);
  }
}
