// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./SAOperator.sol";

// for debugging only
//import "hardhat/console.sol";

interface IApeFactory {

  function isLegitSale(address sale) external view returns (bool);
}

contract SAToken is ERC721, ERC721Enumerable, SAOperator {

  using SafeMath for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  IApeFactory private _factory;

  mapping(uint => bool) private _paused;

  uint256 private _nextTokenId = 1; // will be incremented after  use. 0 reserved for invalid sa

  constructor(
    address factoryAddress
  )
  ERC721("Smart Agreement", "SA")
  {
    _factory = IApeFactory(factoryAddress);
  }

  function pause(uint tokenId) external onlyManager {
    _paused[tokenId] = true;
  }

  function unpause(uint tokenId) external onlyManager {
    delete _paused[tokenId];
  }

  function isPaused(uint tokenId) public view returns (bool){
    return _paused[tokenId];
  }

  function updateFactory(address factoryAddress)
  external virtual
  onlyOwner {
    _factory = IApeFactory(factoryAddress);
  }

  function factory()
  external virtual view
  returns (address)
  {
    return address(_factory);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://metadata.ape.market/smart-agreement/";
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
  internal
  override(ERC721, ERC721Enumerable)
  {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
  public
  view
  override(ERC721, ERC721Enumerable)
  returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _transfer(address from, address to, uint256 tokenId) internal virtual override
  {
    require(!isPaused(tokenId), "SAToken: Token is paused");
    super._transfer(from, to, tokenId);
    _updateBundle(tokenId);
  }

  function mint(address to, uint256 amount) external virtual
  {
    require(
      _factory.isLegitSale(msg.sender),
      "SAToken: Only sale contract can mint its own NFT!"
    );
    _safeMint(to, _tokenIdCounter.current());
    _addBundle(_tokenIdCounter.current(), msg.sender, amount, 0);
    _tokenIdCounter.increment();
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
    _deleteBundle(tokenId);
  }

  function _isApprovedOrOwner(address spender, uint256 tokenId) internal override view virtual returns (bool) {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    if (isPaused(tokenId)) {
      return false;
    }
    address owner = ERC721.ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }

}
