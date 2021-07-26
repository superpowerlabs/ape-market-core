// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Based on:
// https://github.com/sullof/broken-jazz-nft/blob/master/contracts/Signable.sol

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./LevelAccess.sol";

contract Signable is LevelAccess {

    using ECDSA for bytes32;

    event ValidatorUpdated(address _validator);

    address public validator;

    constructor(address _validator){
        validator = _validator;
    }

    function updateValidator(address _validator) external onlyLevel(OWNER_LEVEL) {
        validator = _validator;
        emit ValidatorUpdated(_validator);
    }

    function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool){
        return validator == ECDSA.recover(_hash, _signature);
    }

}
