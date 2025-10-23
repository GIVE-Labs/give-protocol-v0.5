// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../types/GiveTypes.sol";

/// @title GiveStorage
/// @notice Anchors the single shared storage struct used across the GIVE Protocol.
/// @dev Uses diamond storage pattern with deterministic slot calculation.
///      Storage layout is upgrade-safe due to:
///      1. Struct fields with storage gaps protect fixed-size data
///      2. Mappings use dynamic slot calculation (keccak256-based), naturally isolated
///      3. Gap after SystemConfig protects against inter-struct collision
library GiveStorage {
    // keccak256("give.protocol.storage")
    bytes32 internal constant STORAGE_SLOT =
        0x9278f57ecbe047283e665e9a2fb0980ac932c01a01f401ad491194769d990f62;

    /// @dev Root storage struct for the entire GIVE Protocol.
    /// @notice Storage Layout Security:
    ///   - SystemConfig: Fixed-size struct with 50-slot __gap (slots 0-56)
    ///   - __gapAfterSystem: 50 additional slots to prevent collision (slots 57-106)
    ///   - All mappings: Dynamic storage using keccak256(key, slot) - inherently isolated
    ///   - State structs (ngoRegistry, payoutRouter): Contain mappings, documented for safety
    ///
    /// Upgrade Safety Rules:
    ///   1. NEVER reorder existing fields
    ///   2. NEVER change field types
    ///   3. NEVER remove fields (deprecate with comments instead)
    ///   4. Always append new fields at the end
    ///   5. Decrease gap size when adding fields to structs with gaps
    ///   6. Mappings can be added freely (they don't affect layout of other fields)
    struct Store {
        // === Fixed-Size Configuration (Slots 0-56) ===
        GiveTypes.SystemConfig system; // Has internal 50-slot gap
        // Storage gap: Protects against collision between SystemConfig and mappings
        // If SystemConfig adds fields (consuming gap slots), this remains intact
        uint256[50] __gapAfterSystem;
        // === Dynamic Mappings (Slot calculation: keccak256(key, baseSlot)) ===
        // These mappings are inherently isolated from each other and from fixed-size fields
        // Each mapping uses keccak256 hash of (key, slot) for storage location

        // Core protocol mappings
        mapping(bytes32 => GiveTypes.VaultConfig) vaults; // Each VaultConfig has 50-slot gap
        mapping(bytes32 => GiveTypes.AssetConfig) assets; // Each AssetConfig has 50-slot gap
        mapping(bytes32 => GiveTypes.AdapterConfig) adapters; // Each AdapterConfig has 50-slot gap
        mapping(bytes32 => GiveTypes.RiskConfig) riskConfigs; // Each RiskConfig has 50-slot gap
        mapping(bytes32 => GiveTypes.PositionState) positions; // Each PositionState has 50-slot gap
        mapping(bytes32 => GiveTypes.RoleAssignments) roles; // Contains nested mappings
        mapping(bytes32 => GiveTypes.SyntheticAsset) synthetics; // Contains nested mappings
        // Registry state structs (contain nested mappings)
        GiveTypes.NGORegistryState ngoRegistry; // Contains 2 mappings + array
        GiveTypes.PayoutRouterState payoutRouter; // Contains 8 mappings + array
        // Campaign & strategy mappings
        mapping(bytes32 => GiveTypes.StrategyConfig) strategies; // Each StrategyConfig has 50-slot gap
        mapping(bytes32 => GiveTypes.CampaignConfig) campaigns; // Each CampaignConfig has 50-slot gap
        mapping(bytes32 => GiveTypes.CampaignStakeState) campaignStakes; // Contains nested mappings
        mapping(bytes32 => GiveTypes.CampaignCheckpointState) campaignCheckpoints; // Contains nested mappings
        mapping(bytes32 => GiveTypes.CampaignVaultMeta) campaignVaults; // Each CampaignVaultMeta has 50-slot gap
        // Helper mappings for enumeration & lookup
        mapping(bytes32 => address[]) strategyVaults; // Strategy ID -> vault addresses
        mapping(address => bytes32) vaultCampaignLookup; // Vault address -> campaign ID
        // Generic registries for extensibility
        mapping(bytes32 => bytes32) bytes32Registry;
        mapping(bytes32 => uint256) uintRegistry;
        mapping(bytes32 => address) addressRegistry;
        mapping(bytes32 => bool) boolRegistry;

        // Future fields can be added here (mappings are always safe to append)
        // For fixed-size fields, add a new gap and document the consumed slots
    }

    /// @dev Returns the storage pointer for the shared store.
    function store() internal pure returns (Store storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
