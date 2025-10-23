// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GiveProtocolStorage} from "../../core/GiveProtocolStorage.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ModuleBase} from "../utils/ModuleBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AdapterModule
 * @author GIVE Protocol
 * @notice External library for yield adapter management and operations
 * @dev Following YOLO Protocol V1 pattern with external libraries for gas efficiency
 *      Handles adapter registration, activation, invest/divest, and harvest operations
 */
library AdapterModule {
    using SafeERC20 for IERC20;
    using ModuleBase for GiveProtocolStorage.AppStorage;

    // ============================================================
    // EVENTS
    // ============================================================

    event AdapterRegistered(
        address indexed adapter,
        DataTypes.AdapterType indexed adapterType,
        address indexed targetProtocol,
        address vault
    );

    event AdapterActivated(
        address indexed vault,
        address indexed adapter,
        uint256 allocationBps
    );

    event AdapterDeactivated(
        address indexed vault,
        address indexed adapter
    );

    event Invested(
        address indexed vault,
        address indexed adapter,
        uint256 amount,
        uint256 totalInvested
    );

    event Divested(
        address indexed vault,
        address indexed adapter,
        uint256 requested,
        uint256 returned
    );

    event Harvested(
        address indexed vault,
        address indexed adapter,
        uint256 profit,
        uint256 loss,
        uint256 netProfit
    );

    event AdapterAllocationUpdated(
        address indexed vault,
        address indexed adapter,
        uint256 oldAllocationBps,
        uint256 newAllocationBps
    );

    event AdapterPausedChanged(
        address indexed adapter,
        bool isPaused
    );

    // ============================================================
    // ERRORS
    // ============================================================

    error AdapterModule__AdapterExists(address adapter);
    error AdapterModule__AdapterNotFound(address adapter);
    error AdapterModule__AdapterNotActive(address adapter);
    error AdapterModule__AdapterPaused(address adapter);
    error AdapterModule__InsufficientReturns(uint256 expected, uint256 actual);
    error AdapterModule__ExcessiveLoss(uint256 loss, uint256 maxLoss);
    error AdapterModule__InvalidAllocation(uint256 allocation);
    error AdapterModule__MaxAdaptersReached(uint256 max);
    error AdapterModule__AdapterNotInVault(address vault, address adapter);

    // ============================================================
    // ADAPTER REGISTRATION
    // ============================================================

    /**
     * @notice Register new yield adapter
     * @param s Storage reference
     * @param adapter Adapter contract address
     * @param adapterType Type of yield strategy
     * @param targetProtocol External protocol address (Aave, Pendle, etc.)
     * @param vault Vault this adapter will be attached to
     * @return success Registration success
     */
    function registerAdapter(
        GiveProtocolStorage.AppStorage storage s,
        address adapter,
        DataTypes.AdapterType adapterType,
        address targetProtocol,
        address vault
    ) external returns (bool) {
        // Validate inputs
        ModuleBase.requireNonZeroAddress(adapter);
        ModuleBase.requireNonZeroAddress(targetProtocol);
        ModuleBase.requireVaultExists(s, vault);
        
        // Check adapter doesn't already exist
        if (s.isAdapter[adapter]) {
            revert AdapterModule__AdapterExists(adapter);
        }
        
        // Create adapter configuration
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        config.adapterAddress = adapter;
        config.adapterType = adapterType;
        config.targetProtocol = targetProtocol;
        config.vault = vault;
        config.allocationBps = 0; // Not allocated yet
        config.totalInvested = 0;
        config.totalRealized = 0;
        config.totalLoss = 0;
        config.isActive = false; // Not active until explicitly activated
        config.lastHarvestTime = 0;
        config.createdAt = uint40(block.timestamp);
        
        // Register adapter
        s.adapterList.push(adapter);
        s.isAdapter[adapter] = true;
        
        emit AdapterRegistered(adapter, adapterType, targetProtocol, vault);
        
        return true;
    }

    // ============================================================
    // ADAPTER ACTIVATION
    // ============================================================

    /**
     * @notice Activate adapter for a vault with allocation
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @param allocationBps Allocation percentage in basis points (10000 = 100%)
     */
    function activateAdapter(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter,
        uint256 allocationBps
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        
        // Validate allocation
        if (allocationBps == 0 || allocationBps > DataTypes.BASIS_POINTS) {
            revert AdapterModule__InvalidAllocation(allocationBps);
        }
        
        // Check max adapters per vault
        uint256 currentAdapterCount = s.vaultAdapters[vault].length;
        if (currentAdapterCount >= s.riskParams.maxAdaptersPerVault && !_isAdapterInVault(s, vault, adapter)) {
            revert AdapterModule__MaxAdaptersReached(s.riskParams.maxAdaptersPerVault);
        }
        
        // Update adapter configuration
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        uint256 oldAllocation = config.allocationBps;
        config.allocationBps = allocationBps;
        config.isActive = true;
        
        // Add to vault's adapter list if not already present
        if (!_isAdapterInVault(s, vault, adapter)) {
            uint256 index = s.vaultAdapters[vault].length;
            s.vaultAdapters[vault].push(adapter);
            s.vaultAdapterIndex[vault][adapter] = index;
        }
        
        emit AdapterActivated(vault, adapter, allocationBps);
        
        if (oldAllocation != allocationBps) {
            emit AdapterAllocationUpdated(vault, adapter, oldAllocation, allocationBps);
        }
    }

    /**
     * @notice Deactivate adapter from vault
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     */
    function deactivateAdapter(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        
        if (!_isAdapterInVault(s, vault, adapter)) {
            revert AdapterModule__AdapterNotInVault(vault, adapter);
        }
        
        // Update adapter configuration
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        config.isActive = false;
        config.allocationBps = 0;
        
        // Remove from vault's adapter list
        _removeAdapterFromVault(s, vault, adapter);
        
        emit AdapterDeactivated(vault, adapter);
    }

    /**
     * @notice Update adapter allocation
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @param newAllocationBps New allocation in basis points
     */
    function updateAdapterAllocation(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter,
        uint256 newAllocationBps
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        
        if (!_isAdapterInVault(s, vault, adapter)) {
            revert AdapterModule__AdapterNotInVault(vault, adapter);
        }
        
        // Validate allocation
        if (newAllocationBps > DataTypes.BASIS_POINTS) {
            revert AdapterModule__InvalidAllocation(newAllocationBps);
        }
        
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        uint256 oldAllocation = config.allocationBps;
        config.allocationBps = newAllocationBps;
        
        // Deactivate if allocation is 0
        if (newAllocationBps == 0) {
            config.isActive = false;
        }
        
        emit AdapterAllocationUpdated(vault, adapter, oldAllocation, newAllocationBps);
    }

    // ============================================================
    // INVESTMENT OPERATIONS
    // ============================================================

    /**
     * @notice Invest assets into adapter
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @param amount Amount to invest
     * @return invested Amount actually invested
     */
    function invest(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter,
        uint256 amount
    ) external returns (uint256 invested) {
        s.requireHarvestNotPaused();
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        ModuleBase.requireNonZeroAmount(amount);
        
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        
        // Check adapter is active and not paused
        if (!config.isActive) {
            revert AdapterModule__AdapterNotActive(adapter);
        }
        if (s.adapterPaused[adapter]) {
            revert AdapterModule__AdapterPaused(adapter);
        }
        
        // Update tracking
        config.totalInvested += amount;
        
        // Emit event
        emit Invested(vault, adapter, amount, config.totalInvested);
        
        // Note: Actual adapter investment would be called here
        // IYieldAdapter(adapter).invest(amount);
        
        return amount;
    }

    /**
     * @notice Divest assets from adapter
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @param amount Amount to divest
     * @return returned Amount actually returned
     */
    function divest(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter,
        uint256 amount
    ) external returns (uint256 returned) {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        ModuleBase.requireNonZeroAmount(amount);
        
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        DataTypes.VaultConfig storage vaultConfig = s.vaults[vault];
        
        // Note: Actual adapter divestment would be called here
        // returned = IYieldAdapter(adapter).divest(amount);
        returned = amount; // Placeholder
        
        // Check slippage tolerance
        uint256 minReturn = ModuleBase.calculateAfterBps(amount, vaultConfig.slippageToleranceBps);
        
        if (returned < minReturn) {
            revert AdapterModule__InsufficientReturns(minReturn, returned);
        }
        
        // Update tracking (reduce invested amount)
        if (config.totalInvested >= amount) {
            config.totalInvested -= amount;
        }
        
        emit Divested(vault, adapter, amount, returned);
        
        return returned;
    }

    // ============================================================
    // HARVEST OPERATIONS
    // ============================================================

    /**
     * @notice Harvest yield from adapter
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @return result Harvest result with profit/loss details
     */
    function harvest(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter
    ) public returns (DataTypes.HarvestResult memory result) {
        s.requireHarvestNotPaused();
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        
        // Check adapter is active
        if (!config.isActive) {
            revert AdapterModule__AdapterNotActive(adapter);
        }
        
        // Note: Actual harvest would be called here
        // (uint256 profit, uint256 loss) = IYieldAdapter(adapter).harvest();
        uint256 profit = 0; // Placeholder
        uint256 loss = 0;   // Placeholder
        
        // Validate loss is within acceptable limits
        DataTypes.VaultConfig storage vaultConfig = s.vaults[vault];
        uint256 maxAcceptableLoss = ModuleBase.calculateBps(config.totalInvested, vaultConfig.maxLossBps);
        
        if (loss > maxAcceptableLoss) {
            revert AdapterModule__ExcessiveLoss(loss, maxAcceptableLoss);
        }
        
        // Calculate net profit
        uint256 netProfit = profit > loss ? profit - loss : 0;
        
        // Update adapter tracking
        config.totalRealized += profit;
        config.totalLoss += loss;
        config.lastHarvestTime = uint40(block.timestamp);
        
        // Update protocol metrics
        s.metrics.totalYieldGenerated += netProfit;
        
        // Create harvest result
        result = DataTypes.HarvestResult({
            adapter: adapter,
            profit: profit,
            loss: loss,
            netProfit: netProfit,
            timestamp: uint40(block.timestamp)
        });
        
        // Store in harvest history
        s.harvestHistory[adapter].push(result);
        s.lastHarvest[adapter] = uint40(block.timestamp);
        
        emit Harvested(vault, adapter, profit, loss, netProfit);
        
        return result;
    }

    /**
     * @notice Harvest from all active adapters in vault
     * @param s Storage reference
     * @param vault Vault address
     * @return results Array of harvest results
     */
    function harvestAll(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external returns (DataTypes.HarvestResult[] memory results) {
        ModuleBase.requireVaultExists(s, vault);
        
        address[] memory adapters = s.vaultAdapters[vault];
        uint256 activeCount = 0;
        
        // Count active adapters
        for (uint256 i = 0; i < adapters.length; i++) {
            DataTypes.AdapterConfig storage config = s.adapters[adapters[i]];
            if (config.isActive && !s.adapterPaused[adapters[i]]) {
                activeCount++;
            }
        }
        
        // Harvest from active adapters
        results = new DataTypes.HarvestResult[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < adapters.length; i++) {
            address adapter = adapters[i];
            DataTypes.AdapterConfig storage config = s.adapters[adapter];
            
            // Skip inactive or paused adapters
            if (!config.isActive || s.adapterPaused[adapter]) {
                continue;
            }
            
            // Harvest from adapter
            results[index] = harvest(s, vault, adapter);
            index++;
        }
        
        return results;
    }

    // ============================================================
    // PAUSE OPERATIONS
    // ============================================================

    /**
     * @notice Pause or unpause adapter
     * @param s Storage reference
     * @param adapter Adapter address
     * @param isPaused New pause status
     */
    function setAdapterPaused(
        GiveProtocolStorage.AppStorage storage s,
        address adapter,
        bool isPaused
    ) external {
        ModuleBase.requireAdapterExists(s, adapter);
        
        s.adapterPaused[adapter] = isPaused;
        
        emit AdapterPausedChanged(adapter, isPaused);
    }

    // ============================================================
    // QUERY FUNCTIONS
    // ============================================================

    /**
     * @notice Get adapter configuration
     * @param s Storage reference
     * @param adapter Adapter address
     * @return config Adapter configuration
     */
    function getAdapterConfig(
        GiveProtocolStorage.AppStorage storage s,
        address adapter
    ) external view returns (DataTypes.AdapterConfig memory) {
        ModuleBase.requireAdapterExists(s, adapter);
        return s.adapters[adapter];
    }

    /**
     * @notice Get all adapters for a vault
     * @param s Storage reference
     * @param vault Vault address
     * @return adapters Array of adapter addresses
     */
    function getVaultAdapters(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (address[] memory) {
        ModuleBase.requireVaultExists(s, vault);
        return s.vaultAdapters[vault];
    }

    /**
     * @notice Get active adapters for a vault
     * @param s Storage reference
     * @param vault Vault address
     * @return adapters Array of active adapter addresses
     */
    function getActiveVaultAdapters(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (address[] memory) {
        ModuleBase.requireVaultExists(s, vault);
        
        address[] memory allAdapters = s.vaultAdapters[vault];
        uint256 activeCount = 0;
        
        // Count active adapters
        for (uint256 i = 0; i < allAdapters.length; i++) {
            if (s.adapters[allAdapters[i]].isActive && !s.adapterPaused[allAdapters[i]]) {
                activeCount++;
            }
        }
        
        // Populate array
        address[] memory activeAdapters = new address[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allAdapters.length; i++) {
            address adapter = allAdapters[i];
            if (s.adapters[adapter].isActive && !s.adapterPaused[adapter]) {
                activeAdapters[index] = adapter;
                index++;
            }
        }
        
        return activeAdapters;
    }

    /**
     * @notice Get adapter allocation for vault
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @return allocationBps Allocation in basis points
     */
    function getAdapterAllocation(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter
    ) external view returns (uint256) {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireAdapterExists(s, adapter);
        
        return s.adapters[adapter].allocationBps;
    }

    /**
     * @notice Get total invested amount for adapter
     * @param s Storage reference
     * @param adapter Adapter address
     * @return totalInvested Total invested amount
     */
    function getTotalInvested(
        GiveProtocolStorage.AppStorage storage s,
        address adapter
    ) external view returns (uint256) {
        ModuleBase.requireAdapterExists(s, adapter);
        return s.adapters[adapter].totalInvested;
    }

    /**
     * @notice Get harvest history for adapter
     * @param s Storage reference
     * @param adapter Adapter address
     * @return history Array of harvest results
     */
    function getHarvestHistory(
        GiveProtocolStorage.AppStorage storage s,
        address adapter
    ) external view returns (DataTypes.HarvestResult[] memory) {
        ModuleBase.requireAdapterExists(s, adapter);
        return s.harvestHistory[adapter];
    }

    /**
     * @notice Get last harvest timestamp for adapter
     * @param s Storage reference
     * @param adapter Adapter address
     * @return timestamp Last harvest timestamp
     */
    function getLastHarvestTime(
        GiveProtocolStorage.AppStorage storage s,
        address adapter
    ) external view returns (uint40) {
        ModuleBase.requireAdapterExists(s, adapter);
        return s.lastHarvest[adapter];
    }

    /**
     * @notice Check if adapter is operational (active and not paused)
     * @param s Storage reference
     * @param adapter Adapter address
     * @return isOperational True if adapter is operational
     */
    function isAdapterOperational(
        GiveProtocolStorage.AppStorage storage s,
        address adapter
    ) external view returns (bool) {
        if (!s.isAdapter[adapter]) return false;
        
        DataTypes.AdapterConfig storage config = s.adapters[adapter];
        return config.isActive && !s.adapterPaused[adapter] && !s.globalPaused;
    }

    // ============================================================
    // INTERNAL HELPERS
    // ============================================================

    /**
     * @notice Check if adapter is in vault's adapter list
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     * @return exists True if adapter is in vault
     */
    function _isAdapterInVault(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter
    ) private view returns (bool) {
        address[] memory adapters = s.vaultAdapters[vault];
        for (uint256 i = 0; i < adapters.length; i++) {
            if (adapters[i] == adapter) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Remove adapter from vault's adapter list
     * @param s Storage reference
     * @param vault Vault address
     * @param adapter Adapter address
     */
    function _removeAdapterFromVault(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address adapter
    ) private {
        uint256 index = s.vaultAdapterIndex[vault][adapter];
        uint256 lastIndex = s.vaultAdapters[vault].length - 1;
        
        if (index != lastIndex) {
            address lastAdapter = s.vaultAdapters[vault][lastIndex];
            s.vaultAdapters[vault][index] = lastAdapter;
            s.vaultAdapterIndex[vault][lastAdapter] = index;
        }
        
        s.vaultAdapters[vault].pop();
        delete s.vaultAdapterIndex[vault][adapter];
    }
}
