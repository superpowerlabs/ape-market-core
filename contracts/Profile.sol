pragma solidity ^0.8.0;

// Tracks accounts that are associated - belong to same user.
// Similar to bank accounts linkage, both accounts need to confirm the association.
// The association is one-to-one, not transitive. e.g
// A is associated with B, B is associated with C != A is associated with C
contract Profile {
    mapping(address => mapping(address => bool)) _associatedAddresses;

    function setAssociatedAddress(address associatedAddress) external {
        _associatedAddresses[msg.sender][associatedAddress] = true;
    }

    function removeAssociatedAddress(address associatedAddress) external {
        _associatedAddresses[msg.sender][associatedAddress] = false;
    }

    function isMutualAssociatedAddress(address address1, address address2) external view returns(bool) {
        return (_associatedAddresses[address1][address2] && _associatedAddresses[address2][address1]);
    }
}
