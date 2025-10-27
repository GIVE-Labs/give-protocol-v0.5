// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GiveStorage.sol";
import "../types/GiveTypes.sol";

/// @title StorageLib
/// @notice Convenience helpers for reading and writing the shared storage struct.
library StorageLib {
    error StorageNotInitialized();
    error InvalidVault(bytes32 vaultId);
    error InvalidAdapter(bytes32 adapterId);
    error InvalidRisk(bytes32 riskId);
    error InvalidStrategy(bytes32 strategyId);
    error InvalidCampaign(bytes32 campaignId);
    error InvalidCampaignVault(bytes32 vaultId);

    // === Core Accessors ===

    function root() internal pure returns (GiveStorage.Store storage s) {
        return GiveStorage.store();
    }

    function system() internal pure returns (GiveTypes.SystemConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        assembly {
            cfg.slot := s.slot
        }
    }

    function vault(bytes32 vaultId) internal view returns (GiveTypes.VaultConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        cfg = s.vaults[vaultId];
    }

    function adapter(bytes32 adapterId) internal view returns (GiveTypes.AdapterConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        cfg = s.adapters[adapterId];
    }

    function asset(bytes32 assetId) internal view returns (GiveTypes.AssetConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        cfg = s.assets[assetId];
    }

    function riskConfig(bytes32 riskId) internal view returns (GiveTypes.RiskConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        cfg = s.riskConfigs[riskId];
    }

    function ensureRiskConfig(bytes32 riskId) internal view returns (GiveTypes.RiskConfig storage cfg) {
        cfg = riskConfig(riskId);
        if (!cfg.exists) revert InvalidRisk(riskId);
    }

    function position(bytes32 positionId) internal view returns (GiveTypes.PositionState storage state) {
        GiveStorage.Store storage s = GiveStorage.store();
        state = s.positions[positionId];
    }

    function ngoRegistry() internal view returns (GiveTypes.NGORegistryState storage state) {
        GiveStorage.Store storage s = GiveStorage.store();
        state = s.ngoRegistry;
    }

    function payoutRouter() internal view returns (GiveTypes.PayoutRouterState storage state) {
        GiveStorage.Store storage s = GiveStorage.store();
        state = s.payoutRouter;
    }

    function setVaultCampaign(address vaultAddress, bytes32 campaignId) internal {
        GiveStorage.store().vaultCampaignLookup[vaultAddress] = campaignId;
    }

    function getVaultCampaign(address vaultAddress) internal view returns (bytes32) {
        return GiveStorage.store().vaultCampaignLookup[vaultAddress];
    }

    function syntheticState(bytes32 syntheticId) internal view returns (GiveTypes.SyntheticAsset storage synthetic) {
        GiveStorage.Store storage s = GiveStorage.store();
        synthetic = s.synthetics[syntheticId];
    }

    function strategy(bytes32 strategyId) internal view returns (GiveTypes.StrategyConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        cfg = s.strategies[strategyId];
    }

    function ensureStrategy(bytes32 strategyId) internal view returns (GiveTypes.StrategyConfig storage cfg) {
        cfg = strategy(strategyId);
        if (!cfg.exists) revert InvalidStrategy(strategyId);
    }

    function campaign(bytes32 campaignId) internal view returns (GiveTypes.CampaignConfig storage cfg) {
        GiveStorage.Store storage s = GiveStorage.store();
        cfg = s.campaigns[campaignId];
    }

    function ensureCampaign(bytes32 campaignId) internal view returns (GiveTypes.CampaignConfig storage cfg) {
        cfg = campaign(campaignId);
        if (!cfg.exists) revert InvalidCampaign(campaignId);
    }

    function campaignStake(bytes32 campaignId)
        internal
        view
        returns (GiveTypes.CampaignStakeState storage stakeState)
    {
        GiveStorage.Store storage s = GiveStorage.store();
        stakeState = s.campaignStakes[campaignId];
    }

    function campaignCheckpoints(bytes32 campaignId)
        internal
        view
        returns (GiveTypes.CampaignCheckpointState storage checkpointState)
    {
        GiveStorage.Store storage s = GiveStorage.store();
        checkpointState = s.campaignCheckpoints[campaignId];
    }

    function campaignVaultMeta(bytes32 vaultId) internal view returns (GiveTypes.CampaignVaultMeta storage meta) {
        GiveStorage.Store storage s = GiveStorage.store();
        meta = s.campaignVaults[vaultId];
    }

    function ensureCampaignVault(bytes32 vaultId) internal view returns (GiveTypes.CampaignVaultMeta storage meta) {
        meta = campaignVaultMeta(vaultId);
        if (!meta.exists) revert InvalidCampaignVault(vaultId);
    }

    function role(bytes32 roleId) internal view returns (GiveTypes.RoleAssignments storage assignment) {
        GiveStorage.Store storage s = GiveStorage.store();
        assignment = s.roles[roleId];
    }

    function ensureRole(bytes32 roleId) internal view returns (GiveTypes.RoleAssignments storage assignment) {
        assignment = role(roleId);
        if (!assignment.exists) revert InvalidRole(roleId);
    }

    error InvalidRole(bytes32 roleId);

    // === Validation Helpers ===

    function ensureInitialized() internal view {
        if (!system().initialized) revert StorageNotInitialized();
    }

    function ensureVaultActive(bytes32 vaultId) internal view returns (GiveTypes.VaultConfig storage cfg) {
        cfg = vault(vaultId);
        if (cfg.proxy == address(0)) revert InvalidVault(vaultId);
        if (!cfg.active) revert InvalidVault(vaultId);
    }

    function ensureAdapterActive(bytes32 adapterId) internal view returns (GiveTypes.AdapterConfig storage cfg) {
        cfg = adapter(adapterId);
        if (cfg.proxy == address(0) || !cfg.active) {
            revert InvalidAdapter(adapterId);
        }
    }

    // === Registry Helpers ===

    function setAddress(bytes32 key, address value) internal {
        GiveStorage.store().addressRegistry[key] = value;
    }

    function strategyVaults(bytes32 strategyId) internal view returns (address[] storage list) {
        GiveStorage.Store storage s = GiveStorage.store();
        return s.strategyVaults[strategyId];
    }

    function getAddress(bytes32 key) internal view returns (address value) {
        return GiveStorage.store().addressRegistry[key];
    }

    function setUint(bytes32 key, uint256 value) internal {
        GiveStorage.store().uintRegistry[key] = value;
    }

    function getUint(bytes32 key) internal view returns (uint256 value) {
        return GiveStorage.store().uintRegistry[key];
    }

    function setBool(bytes32 key, bool value) internal {
        GiveStorage.store().boolRegistry[key] = value;
    }

    function getBool(bytes32 key) internal view returns (bool value) {
        return GiveStorage.store().boolRegistry[key];
    }

    function setBytes32(bytes32 key, bytes32 value) internal {
        GiveStorage.store().bytes32Registry[key] = value;
    }

    function getBytes32(bytes32 key) internal view returns (bytes32 value) {
        return GiveStorage.store().bytes32Registry[key];
    }
}
