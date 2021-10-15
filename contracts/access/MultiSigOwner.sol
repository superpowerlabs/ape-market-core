// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MultiSigOwner
 * @version 1.0.0
 * @author Francesco Sullo <francesco@sullo.co>
 * @dev A multisig owner to manage contracts
 */

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "./IMultiSigOwner.sol";

contract MultiSigOwner is IMultiSigOwner, Context {
  uint256 public validity;
  address[] private _signersList;
  mapping(address => bool) private _signer;
  mapping(bytes32 => address[]) private _orders;

  modifier onlyValidOrder(uint256 orderTimestamp) {
    require(orderTimestamp < block.timestamp && block.timestamp - orderTimestamp < validity, "MultiSigOwner: order expired");
    _;
  }

  modifier onlySigner() {
    require(_signer[_msgSender()], "MultiSigOwner: not an authorized signer");
    _;
  }

  constructor(address[] memory signersList, uint256 validity_) {
    require(signersList.length > 2, "MultiSigOwner: At least three signers are required");
    for (uint256 i = 0; i < signersList.length; i++) {
      require(!_signer[signersList[i]], "MultiSigOwner: repeated signer");
      _signer[signersList[i]] = true;
    }
    _signersList = signersList;
    validity = validity_;
  }

  function getSigners() external view override returns (address[] memory) {
    return _signersList;
  }

  function quorum() public view override returns (uint256) {
    return (_signersList.length / 2) + 1;
  }

  function getSignersByOrder(bytes32 order) external view override returns (address[] memory) {
    return _orders[order];
  }

  function updateSigners(
    address[] memory signers,
    bool[] memory addRemoves,
    uint256 orderTimestamp
  ) public override onlyValidOrder(orderTimestamp) onlySigner {
    require(signers.length > 0, "MultiSigOwner: no changes");
    require(signers.length == addRemoves.length, "MultiSigOwner: arrays are inconsistent");
    for (uint256 i = 0; i < signers.length; i++) {
      if (addRemoves[i]) {
        require(!_signer[signers[i]], "MultiSigOwner: signer already active");
      } else {
        require(_signer[signers[i]], "MultiSigOwner: signer not found");
      }
      if (i < signers.length - 1) {
        for (uint256 j = i + 1; j < signers.length; j++) {
          require(signers[i] != signers[j], "MultiSigOwner: signer repetition");
        }
      }
    }
    bytes32 order = keccak256(abi.encodePacked(signers, addRemoves, orderTimestamp));
    if (_orderIsReadyForExecution(order)) {
      for (uint256 i = 0; i < signers.length; i++) {
        if (addRemoves[i]) {
          _signer[signers[i]] = true;
          _signersList.push(signers[i]);
        } else {
          delete _signer[signers[i]];
          for (uint256 j = 0; j < _signersList.length; j++) {
            if (_signersList[j] == signers[i]) {
              _signersList[j] = _signersList[_signersList.length - 1];
              _signersList.pop();
              break;
            }
          }
        }
      }
      require(_signersList.length > 2, "MultiSigOwner: At least three signers are required");
      emit SignersUpdated(signers, addRemoves);
    }
  }

  function updateValidity(uint256 validity_, uint256 orderTimestamp) public override onlyValidOrder(orderTimestamp) onlySigner {
    bytes32 order = keccak256(abi.encodePacked(validity_, orderTimestamp));
    if (_orderIsReadyForExecution(order)) {
      validity = validity_;
    }
  }

  function _orderIsReadyForExecution(bytes32 order) internal returns (bool) {
    for (uint256 i = 0; i < _orders[order].length; i++) {
      require(_orders[order][i] != _msgSender(), "MultiSigOwner: signer cannot repeat the same order");
    }
    if (_orders[order].length >= quorum() - 1) {
      // enough signers have previously made the order
      // it executes the order and delete the order from the ledger
      // to avoid that another signer will re-execute it, saving also gas
      delete _orders[order];
      return true;
    } else {
      // add the order to the ledger
      _orders[order].push(_msgSender());
      return false;
    }
  }
}
