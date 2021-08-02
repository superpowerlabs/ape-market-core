// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../utils/IERC20Optimized.sol";
import "../utils/LevelAccess.sol";
import "./ISAToken.sol";
import "./ISATokenExtras.sol";
import "../data/SATokenData.sol";
import "../sale/ISale.sol";
import "../sale/ISaleFactory.sol";

// for debugging only
//import "hardhat/console.sol";

contract SAToken is ISAToken, SATokenData, ERC721, ERC721Enumerable, LevelAccess {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  uint256 public constant MANAGER_LEVEL = 1;
  Counters.Counter private _tokenIdCounter;

  ISaleFactory public factory;
  ISATokenExtras private _extras;

  address public apeWallet;
  IERC20 private _feeToken;
  uint256 public feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer

  modifier feeRequired() {
    uint256 decimals = _feeToken.decimals();
    _feeToken.transferFrom(msg.sender, apeWallet, feeAmount.mul(10**decimals));
    _;
  }

  constructor(
    address saleData,
    address factoryAddress,
    address extrasAddress
  ) ERC721("SA NFT Token", "SANFT") SATokenData(saleData) {
    factory = ISaleFactory(factoryAddress);
    _extras = ISATokenExtras(extrasAddress);
    grantLevel(MANAGER_LEVEL, extrasAddress);
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
    uint256 amount,
    uint128 vestedPercentage
  ) external virtual override {
    address saleAddress = sale;
    if (sale == address(0)) {
      require(
        _extras.isContract(msg.sender) && _saleData.isLegitSale(msg.sender),
        "SAToken: Only legit sales can mint its own NFT!"
      );
      saleAddress = msg.sender;
    } else {
      require(levels[msg.sender] == MANAGER_LEVEL, "SAToken: Only SATokenExtras can mint tokens for an existing sale");
    }
    _mint(to, saleAddress, amount, vestedPercentage);
  }

  function _mint(
    address to,
    address saleAddress,
    uint256 amount,
    uint128 vestedPercentage
  ) internal virtual {
    _safeMint(to, _tokenIdCounter.current());
    require(_bundles[_tokenIdCounter.current()].length == 0, "SAToken: Bundle already exists");
    SA memory sa = SA(saleAddress, amount, vestedPercentage);
    uint256 packedSa = _packSA(sa);
    _bundles[_tokenIdCounter.current()].push(packedSa);
    _tokenIdCounter.increment();
  }

  function nextTokenId() external view virtual override returns (uint256) {
    return _tokenIdCounter.current();
  }

  function vest(uint256 tokenId) public virtual override returns (bool) {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Caller is not NFT owner");
    return _extras.vest(tokenId);
  }

  function burn(uint256 tokenId) external virtual override onlyLevel(MANAGER_LEVEL) {
    _burn(tokenId);
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
  }

  function addSAToBundle(uint256 tokenId, SA memory newSA) external override onlyLevel(MANAGER_LEVEL) {
    _bundles[tokenId].push(_packSA(newSA));
  }

  function getBundle(uint256 tokenId) external view override returns (SA[] memory) {
    SA[] memory sas = new SA[](_bundles[tokenId].length);
    for (uint256 i = 0; i < _bundles[tokenId].length; i++) {
      sas[i] = _unpackUint256(_bundles[tokenId][i]);
    }
    return sas;
  }

  function increaseAmountInSA(
    uint256 tokenId,
    uint256 saIndex,
    uint256 diff
  ) external override onlyLevel(MANAGER_LEVEL) {
    SA memory sa = _unpackUint256(_bundles[tokenId][saIndex]);
    sa.remainingAmount.add(diff);
    _bundles[tokenId][saIndex] = _packSA(sa);
  }

  function merge(uint256[] memory tokenIds) external virtual override feeRequired {
    require(tokenIds.length > 1, "SAToken: are you trying to merge a single token?");
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(ownerOf(tokenIds[i]) == msg.sender, "SAToken: Only owner can merge tokens");
    }
    _extras.merge(tokenIds);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override feeRequired {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Only owner can split a token");
    _extras.split(tokenId, keptAmounts);
  }
}
