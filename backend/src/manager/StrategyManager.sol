// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../vault/GiveVault4626.sol";
import "../interfaces/IYieldAdapter.sol";
import "../utils/Errors.sol";
import "../access/RoleAware.sol";
import {StrategyRegistry} from "./StrategyRegistry.sol";
import {RegistryTypes} from "./RegistryTypes.sol";

/**
 * @title StrategyManager
 * @dev Manages strategy configuration and adapter parameters for GiveVault4626
 * @notice Provides a centralized configuration surface for vault operations
 */
contract StrategyManager is RoleAware, ReentrancyGuard, Pausable {
    // === Cached role ids ===
    bytes32 public immutable STRATEGY_ADMIN_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;

    // === Constants ===
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_ADAPTERS = 10;
    uint256 public constant MIN_REBALANCE_INTERVAL = 1 hours;
    uint256 public constant MAX_REBALANCE_INTERVAL = 30 days;

    // === State Variables ===
    GiveVault4626 public immutable vault;

    mapping(address => bool) public approvedAdapters;
    address[] public adapterList;

    uint256 public rebalanceInterval = 24 hours;
    uint256 public lastRebalanceTime;
    uint256 public emergencyExitThreshold = 1000; // 10% loss threshold

    bool public autoRebalanceEnabled = true;
    bool public emergencyMode;

    /// @notice External registry for approved strategies (optional).
    StrategyRegistry public strategyRegistry;

    // === Events ===
    event AdapterApproved(address indexed adapter, bool approved);
    event AdapterActivated(address indexed adapter);
    event RebalanceIntervalUpdated(uint256 oldInterval, uint256 newInterval);
    event EmergencyThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event AutoRebalanceToggled(bool enabled);
    event EmergencyModeActivated(bool activated);
    event StrategyRebalanced(address indexed oldAdapter, address indexed newAdapter);
    event ParametersUpdated(uint256 cashBufferBps, uint256 slippageBps, uint256 maxLossBps);

    // === Constructor ===
    constructor(address _vault, address roleManager_)
        RoleAware(roleManager_)
    {
        if (_vault == address(0)) {
            revert Errors.ZeroAddress();
        }

        vault = GiveVault4626(payable(_vault));

        STRATEGY_ADMIN_ROLE = roleManager.ROLE_STRATEGY_ADMIN();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();

        lastRebalanceTime = block.timestamp;
    }

    // === Adapter Management ===

    /**
     * @dev Approves or disapproves an adapter for use
     * @param adapter The adapter address
     * @param approved Whether to approve the adapter
     */
    function setAdapterApproval(address adapter, bool approved) external onlyRole(STRATEGY_ADMIN_ROLE) {
        _setAdapterApproval(adapter, approved);
    }

    function _setAdapterApproval(address adapter, bool approved) internal {
        if (adapter == address(0)) revert Errors.ZeroAddress();

        bool wasApproved = approvedAdapters[adapter];
        approvedAdapters[adapter] = approved;

        if (approved && !wasApproved) {
            if (adapterList.length >= MAX_ADAPTERS) {
                revert Errors.ParameterOutOfRange();
            }
            adapterList.push(adapter);
        } else if (!approved && wasApproved) {
            _removeFromAdapterList(adapter);
        }

        emit AdapterApproved(adapter, approved);
    }

    /// @notice Links the manager to a shared strategy registry for adapter discovery.
    function setStrategyRegistry(address registry) external onlyRole(STRATEGY_ADMIN_ROLE) {
        strategyRegistry = StrategyRegistry(registry);
    }

    /// @notice Convenience method to activate a strategy from the registry by id.
    function activateStrategyFromRegistry(uint64 strategyId) external onlyRole(STRATEGY_ADMIN_ROLE) {
        StrategyRegistry registry = strategyRegistry;
        if (address(registry) == address(0)) revert Errors.InvalidConfiguration();

        StrategyRegistry.Strategy memory strategy = registry.getStrategy(strategyId);
        if (strategy.status != RegistryTypes.StrategyStatus.Active) revert Errors.StrategyInactive();

        _setAdapterApproval(strategy.adapter, true);
        _setActiveAdapter(strategy.adapter);
    }

    /**
     * @dev Sets the active adapter for the vault
     * @param adapter The adapter to activate
     */
    function setActiveAdapter(address adapter) external onlyRole(STRATEGY_ADMIN_ROLE) whenNotPaused {
        _setActiveAdapter(adapter);
    }

    function _setActiveAdapter(address adapter) internal whenNotPaused {
        if (adapter != address(0) && !approvedAdapters[adapter]) {
            revert Errors.InvalidAdapter();
        }

        vault.setActiveAdapter(IYieldAdapter(adapter));
        lastRebalanceTime = block.timestamp;

        emit AdapterActivated(adapter);
    }

    // === Parameter Management ===

    /**
     * @dev Updates vault parameters in batch
     * @param cashBufferBps Cash buffer percentage in basis points
     * @param slippageBps Slippage tolerance in basis points
     * @param maxLossBps Maximum loss tolerance in basis points
     */
    function updateVaultParameters(uint256 cashBufferBps, uint256 slippageBps, uint256 maxLossBps)
        external
        onlyRole(STRATEGY_ADMIN_ROLE)
    {
        vault.setCashBufferBps(cashBufferBps);
        vault.setSlippageBps(slippageBps);
        vault.setMaxLossBps(maxLossBps);

        emit ParametersUpdated(cashBufferBps, slippageBps, maxLossBps);
    }

    /**
     * @dev Sets the donation router for the vault
     * @param router The donation router address
     */
    function setDonationRouter(address router) external onlyRole(STRATEGY_ADMIN_ROLE) {
        vault.setDonationRouter(router);
    }

    // === Rebalancing ===

    /**
     * @dev Sets the rebalance interval
     * @param interval New interval in seconds
     */
    function setRebalanceInterval(uint256 interval) external onlyRole(STRATEGY_ADMIN_ROLE) {
        if (interval < MIN_REBALANCE_INTERVAL || interval > MAX_REBALANCE_INTERVAL) {
            revert Errors.ParameterOutOfRange();
        }

        uint256 oldInterval = rebalanceInterval;
        rebalanceInterval = interval;

        emit RebalanceIntervalUpdated(oldInterval, interval);
    }

    /**
     * @dev Toggles auto-rebalancing
     * @param enabled Whether auto-rebalancing is enabled
     */
    function setAutoRebalanceEnabled(bool enabled) external onlyRole(STRATEGY_ADMIN_ROLE) {
        autoRebalanceEnabled = enabled;
        emit AutoRebalanceToggled(enabled);
    }

    /**
     * @dev Manually triggers a rebalance to the best performing adapter
     */
    function rebalance() external onlyRole(STRATEGY_ADMIN_ROLE) whenNotPaused {
        _performRebalance();
    }

    /**
     * @dev Checks if rebalancing is needed and performs it if auto-enabled
     */
    function checkAndRebalance() external {
        if (!autoRebalanceEnabled || emergencyMode) return;
        if (block.timestamp < lastRebalanceTime + rebalanceInterval) return;

        _performRebalance();
    }

    // === Emergency Functions ===

    /**
     * @dev Sets the emergency exit threshold
     * @param threshold Loss threshold in basis points
     */
    function setEmergencyExitThreshold(uint256 threshold) external onlyRole(STRATEGY_ADMIN_ROLE) {
        if (threshold > 5000) revert Errors.ParameterOutOfRange(); // Max 50%

        uint256 oldThreshold = emergencyExitThreshold;
        emergencyExitThreshold = threshold;

        emit EmergencyThresholdUpdated(oldThreshold, threshold);
    }

    /**
     * @dev Activates emergency mode
     */
    function activateEmergencyMode() external onlyRole(GUARDIAN_ROLE) {
        emergencyMode = true;
        vault.emergencyPause();

        emit EmergencyModeActivated(true);
    }

    /**
     * @dev Deactivates emergency mode
     */
    function deactivateEmergencyMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        emergencyMode = false;
        emit EmergencyModeActivated(false);
    }

    /**
     * @dev Emergency withdrawal from current adapter
     */
    function emergencyWithdraw() external onlyRole(GUARDIAN_ROLE) returns (uint256 withdrawn) {
        withdrawn = vault.emergencyWithdrawFromAdapter();
    }

    // === Pause Controls ===

    /**
     * @dev Pauses/unpauses vault investing
     */
    function setInvestPaused(bool paused) external onlyRole(GUARDIAN_ROLE) {
        vault.setInvestPaused(paused);
    }

    /**
     * @dev Pauses/unpauses vault harvesting
     */
    function setHarvestPaused(bool paused) external onlyRole(GUARDIAN_ROLE) {
        vault.setHarvestPaused(paused);
    }

    // === Internal Functions ===

    /**
     * @dev Performs the actual rebalancing logic
     */
    function _performRebalance() internal {
        address currentAdapter = address(vault.activeAdapter());
        address bestAdapter = _findBestAdapter();

        if (bestAdapter != currentAdapter && bestAdapter != address(0)) {
            vault.setActiveAdapter(IYieldAdapter(bestAdapter));
            lastRebalanceTime = block.timestamp;

            emit StrategyRebalanced(currentAdapter, bestAdapter);
        }
    }

    /**
     * @dev Finds the best performing approved adapter
     * @return The address of the best adapter
     */
    function _findBestAdapter() internal view returns (address) {
        if (adapterList.length == 0) return address(0);

        address bestAdapter = adapterList[0];
        uint256 bestYield = 0;

        for (uint256 i = 0; i < adapterList.length; i++) {
            address adapter = adapterList[i];
            if (!approvedAdapters[adapter]) continue;

            // Simple heuristic: adapter with most assets is "best"
            // In production, this would use more sophisticated yield calculations
            try IYieldAdapter(adapter).totalAssets() returns (uint256 assets) {
                if (assets > bestYield) {
                    bestYield = assets;
                    bestAdapter = adapter;
                }
            } catch {
                // Skip adapters that fail
                continue;
            }
        }

        return bestAdapter;
    }

    /**
     * @dev Removes an adapter from the list
     */
    function _removeFromAdapterList(address adapter) internal {
        for (uint256 i = 0; i < adapterList.length; i++) {
            if (adapterList[i] == adapter) {
                adapterList[i] = adapterList[adapterList.length - 1];
                adapterList.pop();
                break;
            }
        }
    }

    // === View Functions ===

    /**
     * @dev Returns the list of approved adapters
     */
    function getApprovedAdapters() external view returns (address[] memory) {
        address[] memory approved = new address[](adapterList.length);
        uint256 count = 0;

        for (uint256 i = 0; i < adapterList.length; i++) {
            if (approvedAdapters[adapterList[i]]) {
                approved[count] = adapterList[i];
                count++;
            }
        }

        // Resize array to actual count
        assembly {
            mstore(approved, count)
        }

        return approved;
    }

    /**
     * @dev Returns strategy configuration
     */
    function getConfiguration()
        external
        view
        returns (
            uint256 rebalanceIntervalValue,
            uint256 emergencyThreshold,
            bool autoRebalance,
            bool emergency,
            uint256 lastRebalance
        )
    {
        return (rebalanceInterval, emergencyExitThreshold, autoRebalanceEnabled, emergencyMode, lastRebalanceTime);
    }

    /**
     * @dev Checks if rebalancing is due
     */
    function isRebalanceDue() external view returns (bool) {
        return autoRebalanceEnabled && !emergencyMode && block.timestamp >= lastRebalanceTime + rebalanceInterval;
    }
}
