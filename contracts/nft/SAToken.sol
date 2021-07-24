// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ISAToken.sol";
import "./ISAStorage.sol";
import "../utils/LevelAccess.sol";

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


contract SAToken is ISAToken, ERC721, ERC721Enumerable, LevelAccess {

  using SafeMath for uint256;
  using Counters for Counters.Counter;

  uint public constant MANAGER_LEVEL = 2;

  Counters.Counter private _tokenIdCounter;

  ISAStorage private _storage;

  ISaleFactory private _factory;

  constructor(address factoryAddress, address storageAddress)
  ERC721("SA NFT Token", "SANFT") {
    _factory = ISaleFactory(factoryAddress);
    _storage = ISAStorage(storageAddress);
  }

  function updateFactory(address factoryAddress) external override virtual
  onlyLevel(OWNER_LEVEL) {
    _factory = ISaleFactory(factoryAddress);
  }

  function updateStorage(address storageAddress) external override virtual
  onlyLevel(OWNER_LEVEL) {
    _storage = ISAStorage(storageAddress);
  }

  function factory() external virtual view override returns (address){
    return address(_factory);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://metadata.ape.market/sanft/";
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal
  override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
    if (from != address(0) && to != address(0)) {
      _storage.updateBundle(tokenId);
    }
  }

  function supportsInterface(bytes4 interfaceId) public view
  override(ERC721, ERC721Enumerable)
  returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mint(address to, uint256 amount) external override virtual {
//    require(isContract(msg.sender), "SAToken: The caller is not a contract");
    require(_factory.isLegitSale(msg.sender), "SAToken: Only legit sales can mint its own NFT!");
    _safeMint(to, _tokenIdCounter.current());
    console.log("Minted %s", _tokenIdCounter.current());
    _storage.addBundleWithSA(_tokenIdCounter.current(), msg.sender, amount, 0);
    _tokenIdCounter.increment();
  }

  function mintWithExistingBundle(address to) external override virtual
  onlyLevel(MANAGER_LEVEL) {
    require(_storage.getBundle(_tokenIdCounter.current()).sas[0].sale != address(0), "SAToken: Bundle does not exists");
    console.log("Minted %s", _tokenIdCounter.current());
    _safeMint(to, _tokenIdCounter.current());
    _tokenIdCounter.increment();
  }

  function nextTokenId() external view virtual override returns(uint) {
    return _tokenIdCounter.current();
  }

  // vest return the number of non empty sas after vest.
  // if there is no non-empty sas, then SA will burned
  function vest(uint256 tokenId) public virtual override
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
      _burn(tokenId);
      return false;
    }
    return true;
  }

  function burn(uint256 tokenId) external virtual override
  onlyLevel(MANAGER_LEVEL) {
    _burn(tokenId);
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
    _storage.deleteBundle(tokenId);
  }

  // from OpenZeppelin Address.sol
//  function isContract(address account) internal view returns (bool) {
//    uint256 size;
//    // solium-disable-next-line security/no-inline-assembly
//    assembly {size := extcodesize(account)}
//    return size > 0;
//  }

}
