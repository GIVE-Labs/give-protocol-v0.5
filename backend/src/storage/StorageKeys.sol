// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title StorageKeys
/// @notice Standard key derivations for the generic registry buckets in StorageLib.
library StorageKeys {
    function vaultKey(bytes32 vaultId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("give.vault.", vaultId));
    }

    function adapterKey(bytes32 adapterId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("give.adapter.", adapterId));
    }

    function roleKey(bytes32 roleId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("give.role.", roleId));
    }

    function syntheticKey(bytes32 assetId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("give.synthetic.", assetId));
    }

    function riskKey(bytes32 riskId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("give.risk.", riskId));
    }

    function bootstrapKey(string memory label) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("give.bootstrap.", label));
    }
}
