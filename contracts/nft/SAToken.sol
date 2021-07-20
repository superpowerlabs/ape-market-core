// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./ISAToken.sol";
import "./ISAStorage.sol";

// for debugging only
import "hardhat/console.sol";

interface ISaleFactory {

  function isLegitSale(address sale) external view returns (bool);
}

interface ISaleMin {

  function getVestedPercentage() external view returns (uint256);

  function getVestedAmount(uint256 vestedPercentage, uint256 lastVestedPercentage, uint256 lockedAmount) external view returns (uint256);

  function vest(address sa_owner, ISAStorage.SA memory sa) external returns (uint, uint);
}


contract SAToken is ISAToken, ERC721, ERC721Enumerable, AccessControl {

  using SafeMath for uint256;
  using Counters for Counters.Counter;

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  Counters.Counter private _tokenIdCounter;

  ISAStorage private _storage;

  ISaleFactory private _factory;

  mapping(uint => bool) private _paused;

  constructor(address factoryAddress, address storageAddress)
  ERC721("Smart Agreement", "SA") {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _factory = ISaleFactory(factoryAddress);
    _storage = ISAStorage(storageAddress);
  }

  function pause(uint tokenId) external override
  onlyRole(PAUSER_ROLE) {
    _paused[tokenId] = true;
  }

  function unpause(uint tokenId) external override
  onlyRole(PAUSER_ROLE) {
    delete _paused[tokenId];
  }

  function pauseBatch(uint[] memory tokenIds) external override
  onlyRole(PAUSER_ROLE) {
    for (uint i = 0; i < tokenIds.length; i++) {
      _paused[tokenIds[i]] = true;
    }
  }

  function unpauseBatch(uint[] memory tokenIds) external override
  onlyRole(PAUSER_ROLE) {
    for (uint i = 0; i < tokenIds.length; i++) {
      delete _paused[tokenIds[i]];
    }
  }

  function isPaused(uint tokenId) public view override returns (bool){
    return _paused[tokenId];
  }

  function updateFactory(address factoryAddress) external override virtual
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _factory = ISaleFactory(factoryAddress);
  }

  function updateStorage(address storageAddress) external override virtual
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _storage = ISAStorage(storageAddress);
  }

  function factory() external virtual view override returns (address){
    return address(_factory);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://metadata.ape.market/smart-agreement/";
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal
  override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view
  override(ERC721, ERC721Enumerable, AccessControl)
  returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _transfer(address from, address to, uint256 tokenId) internal virtual override {
    require(!isPaused(tokenId), "SAToken: Token is paused");
    super._transfer(from, to, tokenId);
    _storage.updateBundle(tokenId);
  }

  function mint(address to, uint256 amount) external override virtual {
    require(isContract(msg.sender), "SAToken: The caller is not a contract");
    require(_factory.isLegitSale(msg.sender), "SAToken: Only legit sales can mint its own NFT!");
    _safeMint(to, _tokenIdCounter.current());
    _storage.addBundle(_tokenIdCounter.current(), msg.sender, amount, 0);
    _tokenIdCounter.increment();
  }

  // vest return the number of non empty sas after vest.
  // if there is no non-empty sas, then SA will burned
  function vest(uint256 tokenId) public virtual
  returns (bool) {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Caller is not NFT owner");
    console.log("vesting", tokenId);
    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    uint256 numEmptySubSAs = 0;
    for (uint256 i = 0; i < bundle.sas.length; i++) {
      ISAStorage.SA memory sa = bundle.sas[i];
      ISaleMin sale = ISaleMin(sa.sale);
      (uint256 vestedPercentage, uint256 vestedAmount) = sale.vest(ownerOf(tokenId), sa);
      console.log("vesting", tokenId, vestedAmount);
      if (vestedPercentage == 100) {
        numEmptySubSAs++;
      }
      _storage.updateSA(tokenId, i, vestedPercentage, vestedAmount);
    }
    if (numEmptySubSAs == bundle.sas.length) {
      _storage.deleteBundle(tokenId);
      _burn(tokenId);
      return false;
    }
    return true;
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
    _storage.deleteBundle(tokenId);
  }

  function _isApprovedOrOwner(address spender, uint256 tokenId) internal override view virtual returns (bool) {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    if (isPaused(tokenId)) {
      return false;
    }
    address owner = ERC721.ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }

  // from OpenZeppelin Address.sol
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // solium-disable-next-line security/no-inline-assembly
    assembly {size := extcodesize(account)}
    return size > 0;
  }

//  function cleanSA(uint tokenId) external {
//    require(ownerOf(tokenId) == msg.sender, "SAToken: Caller is not NFT owner");
////    _storage.cleanEmptySAs(tokenId, numEmptySubSAs);
//  }

}
