// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GiveProtocolStorage} from "../../core/GiveProtocolStorage.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ModuleBase} from "../utils/ModuleBase.sol";

/**
 * @title VaultModule
 * @author GIVE Protocol
 * @notice External library for vault creation and management
 * @dev Following YOLO Protocol V1 pattern with external libraries for gas efficiency
 *      Handles vault registration, configuration, and lifecycle management
 */
library VaultModule {
    using ModuleBase for GiveProtocolStorage.AppStorage;

    // ============================================================
    // EVENTS
    // ============================================================

    event VaultCreated(
        address indexed vault,
        address indexed asset,
        address indexed strategyManager,
        string name,
        string symbol
    );

    event VaultConfigured(
        address indexed vault,
        uint256 cashReserveBps,
        uint256 slippageToleranceBps,
        uint256 maxLossBps
    );

    event VaultStatusChanged(
        address indexed vault,
        bool isActive,
        bool isPaused
    );

    event VaultParametersUpdated(
        address indexed vault,
        uint256 cashReserveBps,
        uint256 slippageToleranceBps,
        uint256 maxLossBps
    );

    event VaultMetricsUpdated(
        address indexed vault,
        uint256 totalAssets,
        uint256 totalShares
    );

    // ============================================================
    // ERRORS
    // ============================================================

    error VaultModule__VaultExists(address vault);
    error VaultModule__VaultNotFound(address vault);
    error VaultModule__InvalidParameters(string reason);
    error VaultModule__VaultNotActive(address vault);
    error VaultModule__VaultPaused(address vault);

    // ============================================================
    // VAULT CREATION
    // ============================================================

    /**
     * @notice Register new vault in protocol
     * @param s Storage reference
     * @param vault Vault address (pre-deployed)
     * @param asset Underlying asset
     * @param strategyManager Strategy manager contract
     * @param campaignRegistry Campaign registry contract
     * @param name Vault name
     * @param symbol Vault symbol
     * @param cashReserveBps Cash reserve in basis points
     * @return vaultAddress Registered vault address
     */
    function registerVault(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address asset,
        address strategyManager,
        address campaignRegistry,
        string memory name,
        string memory symbol,
        uint256 cashReserveBps
    ) external returns (address) {
        // Validate inputs
        ModuleBase.requireNonZeroAddress(vault);
        ModuleBase.requireNonZeroAddress(asset);
        ModuleBase.requireNonZeroAddress(strategyManager);
        
        // Check vault doesn't already exist
        if (s.isVault[vault]) {
            revert VaultModule__VaultExists(vault);
        }
        
        // Validate cash reserve
        if (
            cashReserveBps < DataTypes.MIN_CASH_RESERVE_BPS ||
            cashReserveBps > s.riskParams.maxCashReserveBps
        ) {
            revert VaultModule__InvalidParameters("Invalid cash reserve");
        }
        
        // Create vault configuration
        DataTypes.VaultConfig storage config = s.vaults[vault];
        config.asset = asset;
        config.vaultToken = vault;
        config.strategyManager = strategyManager;
        config.campaignRegistry = campaignRegistry;
        config.cashReserveBps = cashReserveBps;
        config.slippageToleranceBps = 50; // Default 0.5%
        config.maxLossBps = 50; // Default 0.5%
        config.totalAssets = 0;
        config.totalShares = 0;
        config.isActive = true;
        config.isPaused = false;
        config.createdAt = uint40(block.timestamp);
        
        // Register vault
        s.vaultList.push(vault);
        s.isVault[vault] = true;
        
        // Update metrics
        s.metrics.totalCampaigns++; // Increment as each vault can have campaigns
        
        emit VaultCreated(vault, asset, strategyManager, name, symbol);
        emit VaultConfigured(vault, cashReserveBps, 50, 50);
        
        return vault;
    }

    // ============================================================
    // VAULT CONFIGURATION
    // ============================================================

    /**
     * @notice Update vault parameters
     * @param s Storage reference
     * @param vault Vault address
     * @param cashReserveBps New cash reserve
     * @param slippageToleranceBps New slippage tolerance
     * @param maxLossBps New max loss
     */
    function updateVaultParameters(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        uint256 cashReserveBps,
        uint256 slippageToleranceBps,
        uint256 maxLossBps
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        
        // Validate parameters against risk limits
        if (cashReserveBps > s.riskParams.maxCashReserveBps) {
            revert VaultModule__InvalidParameters("Cash reserve too high");
        }
        if (slippageToleranceBps > s.riskParams.maxSlippageBps) {
            revert VaultModule__InvalidParameters("Slippage too high");
        }
        if (maxLossBps > s.riskParams.maxLossBps) {
            revert VaultModule__InvalidParameters("Max loss too high");
        }
        
        // Update configuration
        DataTypes.VaultConfig storage config = s.vaults[vault];
        config.cashReserveBps = cashReserveBps;
        config.slippageToleranceBps = slippageToleranceBps;
        config.maxLossBps = maxLossBps;
        
        emit VaultParametersUpdated(
            vault,
            cashReserveBps,
            slippageToleranceBps,
            maxLossBps
        );
    }

    /**
     * @notice Update vault active status
     * @param s Storage reference
     * @param vault Vault address
     * @param isActive New active status
     */
    function setVaultActive(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        bool isActive
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        
        DataTypes.VaultConfig storage config = s.vaults[vault];
        config.isActive = isActive;
        
        emit VaultStatusChanged(vault, isActive, config.isPaused);
    }

    /**
     * @notice Pause or unpause vault
     * @param s Storage reference
     * @param vault Vault address
     * @param isPaused New pause status
     */
    function setVaultPaused(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        bool isPaused
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        
        DataTypes.VaultConfig storage config = s.vaults[vault];
        config.isPaused = isPaused;
        s.vaultPaused[vault] = isPaused;
        
        emit VaultStatusChanged(vault, config.isActive, isPaused);
    }

    // ============================================================
    // VAULT METRICS
    // ============================================================

    /**
     * @notice Update vault total assets and shares
     * @param s Storage reference
     * @param vault Vault address
     * @param totalAssets New total assets
     * @param totalShares New total shares
     */
    function updateVaultMetrics(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        uint256 totalAssets,
        uint256 totalShares
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        
        DataTypes.VaultConfig storage config = s.vaults[vault];
        
        // Calculate TVL delta
        uint256 oldAssets = config.totalAssets;
        int256 assetsDelta = int256(totalAssets) - int256(oldAssets);
        
        // Update vault metrics
        config.totalAssets = totalAssets;
        config.totalShares = totalShares;
        
        // Update protocol TVL
        if (assetsDelta > 0) {
            s.metrics.totalValueLocked += uint256(assetsDelta);
        } else if (assetsDelta < 0) {
            s.metrics.totalValueLocked -= uint256(-assetsDelta);
        }
        
        emit VaultMetricsUpdated(vault, totalAssets, totalShares);
    }

    // ============================================================
    // VAULT QUERIES
    // ============================================================

    /**
     * @notice Get vault configuration
     * @param s Storage reference
     * @param vault Vault address
     * @return config Vault configuration
     */
    function getVaultConfig(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (DataTypes.VaultConfig memory) {
        ModuleBase.requireVaultExists(s, vault);
        return s.vaults[vault];
    }

    /**
     * @notice Check if vault is active and not paused
     * @param s Storage reference
     * @param vault Vault address
     * @return isOperational True if vault is operational
     */
    function isVaultOperational(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (bool) {
        if (!s.isVault[vault]) return false;
        
        DataTypes.VaultConfig storage config = s.vaults[vault];
        return config.isActive && !config.isPaused && !s.globalPaused;
    }

    /**
     * @notice Get all vaults
     * @param s Storage reference
     * @return vaults Array of vault addresses
     */
    function getAllVaults(
        GiveProtocolStorage.AppStorage storage s
    ) external view returns (address[] memory) {
        return s.vaultList;
    }

    /**
     * @notice Get active vaults
     * @param s Storage reference
     * @return vaults Array of active vault addresses
     */
    function getActiveVaults(
        GiveProtocolStorage.AppStorage storage s
    ) external view returns (address[] memory) {
        uint256 activeCount = 0;
        uint256 length = s.vaultList.length;
        
        // Count active vaults
        for (uint256 i = 0; i < length; i++) {
            if (s.vaults[s.vaultList[i]].isActive) {
                activeCount++;
            }
        }
        
        // Populate array
        address[] memory activeVaults = new address[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < length; i++) {
            address vault = s.vaultList[i];
            if (s.vaults[vault].isActive) {
                activeVaults[index] = vault;
                index++;
            }
        }
        
        return activeVaults;
    }

    /**
     * @notice Get vault total value locked
     * @param s Storage reference
     * @param vault Vault address
     * @return tvl Total value locked
     */
    function getVaultTVL(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (uint256) {
        ModuleBase.requireVaultExists(s, vault);
        return s.vaults[vault].totalAssets;
    }

    /**
     * @notice Calculate required cash reserve for vault
     * @param s Storage reference
     * @param vault Vault address
     * @param totalAssets Total assets in vault
     * @return reserve Required cash reserve amount
     */
    function calculateCashReserve(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        uint256 totalAssets
    ) external view returns (uint256) {
        ModuleBase.requireVaultExists(s, vault);
        
        uint256 reserveBps = s.vaults[vault].cashReserveBps;
        return ModuleBase.calculateBps(totalAssets, reserveBps);
    }
}
