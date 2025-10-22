// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../types/GiveTypes.sol";

/// @title GiveStorage
/// @notice Anchors the single shared storage struct used across the GIVE Protocol.
library GiveStorage {
    // keccak256("give.protocol.storage")
    bytes32 internal constant STORAGE_SLOT = 0x9278f57ecbe047283e665e9a2fb0980ac932c01a01f401ad491194769d990f62;

    struct Store {
        GiveTypes.SystemConfig system;
        mapping(bytes32 => GiveTypes.VaultConfig) vaults;
        mapping(bytes32 => GiveTypes.AssetConfig) assets;
        mapping(bytes32 => GiveTypes.AdapterConfig) adapters;
        mapping(bytes32 => GiveTypes.RiskConfig) riskConfigs;
        mapping(bytes32 => GiveTypes.PositionState) positions;
        mapping(bytes32 => GiveTypes.RoleAssignments) roles;
        mapping(bytes32 => GiveTypes.SyntheticAsset) synthetics;
        GiveTypes.DonationRouterState donationRouter;
        GiveTypes.NGORegistryState ngoRegistry;
        mapping(bytes32 => bytes32) bytes32Registry;
        mapping(bytes32 => uint256) uintRegistry;
        mapping(bytes32 => address) addressRegistry;
        mapping(bytes32 => bool) boolRegistry;
    }

    /// @dev Returns the storage pointer for the shared store.
    function store() internal pure returns (Store storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
