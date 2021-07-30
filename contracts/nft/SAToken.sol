// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ISAToken.sol";
import "./ISAStorage.sol";
import "../sale/ISale.sol";
import "../utils/LevelAccess.sol";
import "../user/IProfile.sol";

// for debugging only
import "hardhat/console.sol";

interface ISaleFactory {

  function isLegitSale(address sale) external view returns (bool);
}


contract SAToken is ISAToken, ERC721, ERC721Enumerable, LevelAccess {

  using SafeMath for uint256;
  using Counters for Counters.Counter;

  uint256 public constant MANAGER_LEVEL = 2;

  Counters.Counter private _tokenIdCounter;

  ISAStorage private _storage;
  ISaleFactory private _factory;
  IProfile private _profile;

  constructor(address factoryAddress, address storageAddress, address profileAddress)
  ERC721("SA NFT Token", "SANFT") {
    _factory = ISaleFactory(factoryAddress);
    _storage = ISAStorage(storageAddress);
    _profile = IProfile(profileAddress);
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
//    console.log("Transfer from %s to %s", from, to);
    if (from != address(0) && to != address(0)) {
      if (!_profile.areAccountsAssociated(from, to)) {
        // check if any sale is not transferable
        ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
        for (uint256 i = 0; i < bundle.sas.length; i++) {
          ISale sale = ISale(bundle.sas[i].sale);
//          console.log(sale.isTransferable());
          if (!sale.isTransferable()) {
            revert("SAToken: token not transferable");
          }
        }
      }
      _storage.updateBundle(tokenId);
    }
  }

  function supportsInterface(bytes4 interfaceId) public view
  override(ERC721, ERC721Enumerable)
  returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function mint(address to, address sale, uint256 amount, uint128 vestedPercentage) external override virtual {
    address saleAddress = sale;
    if (sale == address(0)) {
      require(isContract(msg.sender) && _factory.isLegitSale(msg.sender), "SAToken: Only legit sales can mint its own NFT!");
      saleAddress = msg.sender;
    } else {
      require(levels[msg.sender] == MANAGER_LEVEL, "SAToken: Only SAManager can mint tokens for an existing sale");
    }
    _mint(to, saleAddress, amount, vestedPercentage);
  }

  function _mint(address to, address saleAddress, uint256 amount, uint128 vestedPercentage) internal virtual {
    _safeMint(to, _tokenIdCounter.current());
    _storage.newBundleWithSA(_tokenIdCounter.current(), saleAddress, amount, vestedPercentage);
    _tokenIdCounter.increment();
  }

  function nextTokenId() external view virtual override returns (uint256) {
    return _tokenIdCounter.current();
  }

  // vest return the number of non empty sas after vest.
  // if there is no non-empty sas, then SA will burned
  function vest(uint256 tokenId) public virtual override
  returns (bool) {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Caller is not NFT owner");
//    console.log("vesting", tokenId);
    // console.log("gas left before vesting", gasleft());
    ISAStorage.Bundle memory bundle = _storage.getBundle(tokenId);
    uint256 nextId = _tokenIdCounter.current();
    bool notEmtpy;
    bool minted;
    for (uint256 i = 0; i < bundle.sas.length; i++) {
      ISAStorage.SA memory sa = bundle.sas[i];
      ISale sale = ISale(sa.sale);
      (uint128 vestedPercentage, uint256 vestedAmount) = sale.vest(ownerOf(tokenId), sa);
//      console.log("vesting", tokenId, vestedAmount);
      if (vestedPercentage != 100) {
        // we skip vested SAs
        if (!minted) {
          _mint(msg.sender, sa.sale, vestedAmount, vestedPercentage);
          // console.log("gas left after mint", gasleft());
          minted = true;
        } else {
          ISAStorage.SA memory newSA = ISAStorage.SA(sa.sale, vestedAmount, vestedPercentage);
          _storage.addSAToBundle(nextId, newSA);
          // console.log("gas left after addNewSA", gasleft());
        }
        notEmtpy = true;
      }
    }
    _burn(tokenId);
    return notEmtpy;
  }

  function burn(uint256 tokenId) external virtual override
  onlyLevel(MANAGER_LEVEL) {
    _burn(tokenId);
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
    // console.log("gas left after burn", gasleft());
    _storage.deleteBundle(tokenId);
    // console.log("gas left after delete bundle", gasleft());
  }

  // from OpenZeppelin's Address.sol
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // solium-disable-next-line security/no-inline-assembly
    assembly {size := extcodesize(account)}
    return size > 0;
  }

}
