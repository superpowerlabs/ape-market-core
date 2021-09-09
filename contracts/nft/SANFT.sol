// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./ISANFT.sol";
import "./ISANFTManager.sol";
import "../sale/ISale.sol";
import "../registry/RegistryUser.sol";

contract SANFT is ISANFT, RegistryUser, ERC721, ERC721Enumerable {
  using SafeMath for uint256;

  bytes32 internal constant _SANFT_MANAGER = keccak256("SANFTManager");

  uint256 private _nextTokenId = 1;

  mapping(uint256 => SA[]) internal _bundles;

  modifier onlyTokenOwner(uint256 tokenId) {
    require(ownerOf(tokenId) == _msgSender(), "SANFT: only token owner can call this");
    _;
  }

  modifier onlySANFTManager() {
    require(address(_sanftmanager) == _msgSender(), "SANFT: only SANFTManager can call this");
    _;
  }

  constructor(address apeRegistry_) RegistryUser(apeRegistry_) ERC721("SA NFT Token", "SANFT") {}

  ISANFTManager private _sanftmanager;

  function updateRegisteredContracts() external virtual override onlyRegistry {
    address addr = _get(_SANFT_MANAGER);
    if (addr != address(_sanftmanager)) {
      _sanftmanager = ISANFTManager(addr);
    }
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
      _sanftmanager.beforeTokenTransfer(from, to, tokenId);
    }
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, IERC165) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mint(
    address recipient,
    uint16 saleId,
    uint120 fullAmount,
    uint120 remainingAmount
  ) external virtual override onlySANFTManager {
    require(_bundles[_nextTokenId].length == 0, "SANFT: Bundle already exists");
    _safeMint(recipient, _nextTokenId);
    _bundles[_nextTokenId].push(SA(saleId, fullAmount, remainingAmount));
    _nextTokenId++;
  }

  function mint(address recipient, SA[] memory bundle) public virtual override onlySANFTManager {
    require(_bundles[_nextTokenId].length == 0, "SANFT: Bundle already exists");
    _safeMint(recipient, _nextTokenId);
    for (uint256 i = 0; i < bundle.length; i++) {
      _bundles[_nextTokenId].push(bundle[i]);
    }
    _nextTokenId++;
  }

  function nextTokenId() external view virtual override returns (uint256) {
    return _nextTokenId;
  }

  function withdraw(uint256 tokenId, uint256[] memory amounts) external virtual override onlyTokenOwner(tokenId) {
    _sanftmanager.withdraw(tokenId, amounts);
  }

  function withdrawables(uint256 tokenId) external view override returns (uint16[] memory, uint256[] memory) {
    return _sanftmanager.withdrawables(tokenId);
  }

  function burn(uint256 tokenId) external virtual override onlySANFTManager {
    delete _bundles[tokenId];
    _burn(tokenId);
  }

  function addSAToBundle(uint256 tokenId, SA memory newSA) external override onlySANFTManager {
    _bundles[tokenId].push(newSA);
  }

  function getBundle(uint256 tokenId) external view override returns (SA[] memory) {
    return _bundles[tokenId];
  }
}
