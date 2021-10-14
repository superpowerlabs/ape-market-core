// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiSigRegistryOwner
 * @version 1.0.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A multisig manager for the ApeRegistry
 */

import "@openzeppelin/contracts/utils/Context.sol";
import "./IApeRegistry.sol";

contract MultiSigRegistryOwner is Context {

  IApeRegistry private _apeRegistry;

  address[] public signersList;
  mapping(address => bool) private _signer;

  uint public validity;

  mapping(bytes32 => address[]) public orderLedger;

  modifier isDayValid(uint orderTimestamp) {
    require(orderTimestamp < block.timestamp && block.timestamp - orderTimestamp < validity, "MultiSigRegistryOwner: order expired");
    _;
  }

  modifier isSigner() {
    require(_signer[_msgSender()], "MultiSigRegistryOwner: not an authorized signer");
  }

  constructor(address apeRegistry, address[] memory signersList_, uint validity_) {
    require(signers_.length > 2, "MultiSigRegistryOwner: At least 3 signers are required");
    _apeRegistry = apeRegistry;
    signersList = signersList_;
    for (uint i = 0; i < signersList_.length; i++) {
      _signer[signerList_[i]] = true;
    }
    validity = validity_; // < 24 hours
  }

  function quorum() public view returns (uint) {
    return (signers.length / 2) + 1;
  }

  /*
    orderTimestamp identifies the operation and must be passed by any signers and since
    then there is a validity period to complete the execution. If not the process must
    be restarted
  */
  function register(bytes32[] memory contractHashes, address[] memory addrs, uint orderTimestamp) external
  isTimestampValid(orderTimestamp) isSigner {

    bytes32 order = keccak256(
      abi.encodePacked(
        "register",
        contractHashes,
        addrs,
        orderTimestamp
      ));

    address[] memory previousSigners = orderLedger[order];
    if (previousSigners.length >= quorum() - 1) {
      // enough signers have previousvly made the order
      _apeRegistry.register(contractHashes, addrs);
    } else {
      // add the order to the ledger


    }

  }

  function get(bytes32 contractHash) external view returns (address);

  function updateContracts(uint256 initialIndex, uint256 limit) external;

  function updateAllContracts() external;


}
