// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../utils/IERC20Optimized.sol";
import "./ISAToken.sol";
import "./SAStorage.sol";
import "../sale/ISale.sol";
import "./ISATokenExtras.sol";

// for debugging only
//import "hardhat/console.sol";

interface ISaleFactory {

  function isLegitSale(address sale) external view returns (bool);
}

contract SAToken is ISAToken, ERC721, ERC721Enumerable, SAStorage {

  using SafeMath for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  ISaleFactory public factory;
  ISATokenExtras private _extras;

  address public apeWallet;
  IERC20 private _feeToken;
  uint256 public feeAmount; // the amount of fee in _feeToken charged for merge, split and transfer


  modifier feeRequired() {
    uint256 decimals = _feeToken.decimals();
    _feeToken.transferFrom(msg.sender, apeWallet, feeAmount.mul(10 ** decimals));
    _;
  }

  constructor(address factoryAddress, address extrasAddress)
  ERC721("SA NFT Token", "SANFT") {
    factory = ISaleFactory(factoryAddress);
    _extras = ISATokenExtras(extrasAddress);
    grantLevel(MANAGER_LEVEL, extrasAddress);
  }

  function getTokenExtras() external view override returns(address) {
    return address(_extras);
  }

  function updateFactory(address factoryAddress) external virtual
  onlyLevel(OWNER_LEVEL) {
    factory = ISaleFactory(factoryAddress);
  }

  function setupUpPayments(address feeToken, uint256 feeAmount_, address apeWallet_) external virtual
  onlyLevel(OWNER_LEVEL) {
    _feeToken = IERC20(feeToken);
    feeAmount = feeAmount_;
    apeWallet = apeWallet_;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://metadata.ape.market/sanft/";
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal
  override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
    if (from != address(0) && to != address(0)) {
      _extras.beforeTokenTransfer(from, to, tokenId);
      // do we need this: ?
//      _updateBundleAcquisitionTime(tokenId);
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
      require(isContract(msg.sender) && factory.isLegitSale(msg.sender), "SAToken: Only legit sales can mint its own NFT!");
      saleAddress = msg.sender;
    } else {
      require(levels[msg.sender] == MANAGER_LEVEL, "SAToken: Only SATokenExtras can mint tokens for an existing sale");
    }
    _mint(to, saleAddress, amount, vestedPercentage);
  }

  function _mint(address to, address saleAddress, uint256 amount, uint128 vestedPercentage) internal virtual {
    _safeMint(to, _tokenIdCounter.current());
    _newBundleWithSA(_tokenIdCounter.current(), saleAddress, amount, vestedPercentage);
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
    return _extras.vest(tokenId);
//    //    console.log("vesting", tokenId);
//    // console.log("gas left before vesting", gasleft());
//    ISAStorage.Bundle memory bundle = getBundle(tokenId);
//    uint256 nextId = _tokenIdCounter.current();
//    bool notEmtpy;
//    bool minted;
//    for (uint256 i = 0; i < bundle.sas.length; i++) {
//      ISAStorage.SA memory sa = bundle.sas[i];
//      ISale sale = ISale(sa.sale);
//      (uint128 vestedPercentage, uint256 vestedAmount) = sale.vest(ownerOf(tokenId), sa);
//      //      console.log("vesting", tokenId, vestedAmount);
//      if (vestedPercentage != 100) {
//        // we skip vested SAs
//        if (!minted) {
//          _mint(msg.sender, sa.sale, vestedAmount, vestedPercentage);
//          // console.log("gas left after mint", gasleft());
//          minted = true;
//        } else {
//          ISAStorage.SA memory newSA = ISAStorage.SA(sa.sale, vestedAmount, vestedPercentage);
//          _addSAToBundle(nextId, newSA);
//          // console.log("gas left after addNewSA", gasleft());
//        }
//        notEmtpy = true;
//      }
//    }
//    _burn(tokenId);
//    return notEmtpy;
  }

  function burn(uint256 tokenId) external virtual override
  onlyLevel(MANAGER_LEVEL) {
    _burn(tokenId);
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
    _deleteBundle(tokenId);
  }

  function merge(uint256[] memory tokenIds) external virtual override feeRequired {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(ownerOf(tokenIds[i]) == msg.sender, "SAToken: Only owner can merge tokens");
    }
    _extras.merge(tokenIds);
  }

  function split(uint256 tokenId, uint256[] memory keptAmounts) public virtual override feeRequired {
    require(ownerOf(tokenId) == msg.sender, "SAToken: Only owner can split a token");
    _extras.split(tokenId, keptAmounts);
  }

  // from OpenZeppelin's Address.sol
  function isContract(address account) internal view returns (bool) {
    uint256 size;
    // solium-disable-next-line security/no-inline-assembly
    assembly {size := extcodesize(account)}
    return size > 0;
  }

}
