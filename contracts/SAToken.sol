// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// for debugging only
//import "hardhat/console.sol";

interface ISAStorage {

  function addBundle(uint bundleId, address saleAddress, uint256 remainingAmount, uint256 vestedPercentage) external returns (uint);

  function deleteBundle(uint bundleId) external;

  function updateBundle(uint bundleId) external returns (bool);

}

interface IApeFactory {

  function isLegitSale(address sale) external view returns (bool);
}

contract SAToken is ERC721, ERC721Enumerable, AccessControl {

  using SafeMath for uint256;
  using Counters for Counters.Counter;

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

  Counters.Counter private _tokenIdCounter;

  ISAStorage private _storage;

  IApeFactory private _factory;

  mapping(uint => bool) private _paused;

  constructor(address factoryAddress, address storageAddress)
  ERC721("Smart Agreement", "SA") {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _factory = IApeFactory(factoryAddress);
    _storage = ISAStorage(storageAddress);
  }

  function pause(uint tokenId) external
  onlyRole(PAUSER_ROLE) {
    _paused[tokenId] = true;
  }

  function unpause(uint tokenId) external
  onlyRole(PAUSER_ROLE) {
    delete _paused[tokenId];
  }

  function pauseBatch(uint[] tokenIds) external
  onlyRole(PAUSER_ROLE) {
    for (uint i = 0; i < tokenIds.length; i++) {
      _paused[tokenIds[i]] = true;
    }
  }

  function unpauseBatch(uint[] tokenIds) external
  onlyRole(PAUSER_ROLE) {
    for (uint i = 0; i < tokenIds.length; i++) {
      delete _paused[tokenIds[i]];
    }
  }

  function isPaused(uint tokenId) public view returns (bool){
    return _paused[tokenId];
  }

  function updateFactory(address factoryAddress) external virtual
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _factory = IApeFactory(factoryAddress);
  }

  function updateStorage(address storageAddress) external virtual
  onlyRole(DEFAULT_ADMIN_ROLE) {
    _storage = ISAStorage(storageAddress);
  }

  function factory() external virtual view returns (address){
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

  function mint(address to, uint256 amount) external virtual {
    require(isContract(msg.sender), "SAToken: The caller is not a contract");
    require(_factory.isLegitSale(msg.sender), "SAToken: Only legit sales can mint its own NFT!");
    _safeMint(to, _tokenIdCounter.current());
    _storage.addBundle(_tokenIdCounter.current(), msg.sender, amount, 0);
    _tokenIdCounter.increment();
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

}
