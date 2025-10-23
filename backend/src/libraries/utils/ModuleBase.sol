// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GiveProtocolStorage} from "../../core/GiveProtocolStorage.sol";
import {DataTypes} from "../types/DataTypes.sol";

/**
 * @title ModuleBase
 * @author GIVE Protocol
 * @notice Base library providing common utilities for all modules
 * @dev Following YOLO Protocol V1 pattern for shared module functionality
 *      Provides role checks, pause checks, validation, and common helpers
 */
library ModuleBase {
    // ============================================================
    // EVENTS
    // ============================================================

    event ModuleAction(
        string indexed module,
        string action,
        address indexed actor,
        bytes data
    );

    event PauseStateChanged(
        string context,
        bool isPaused,
        address indexed actor
    );

    // ============================================================
    // ERRORS
    // ============================================================

    error ModuleBase__Unauthorized(address caller, bytes32 requiredRole);
    error ModuleBase__InvalidInput(string reason);
    error ModuleBase__OperationPaused(string operation);
    error ModuleBase__InvalidAddress(address addr);
    error ModuleBase__InvalidAmount(uint256 amount);
    error ModuleBase__InvalidBps(uint256 bps, uint256 max);
    error ModuleBase__Reentrancy();
    error ModuleBase__VaultNotFound(address vault);
    error ModuleBase__AdapterNotFound(address adapter);
    error ModuleBase__CampaignNotFound(bytes32 campaignId);
    error ModuleBase__InsufficientBalance(uint256 available, uint256 required);

    // ============================================================
    // CONSTANTS
    // ============================================================

    /// @notice Reentrancy guard constants
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    /// @notice Role constants
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER");
    bytes32 internal constant CAMPAIGN_CURATOR_ROLE = keccak256("CAMPAIGN_CURATOR");
    bytes32 internal constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER");
    bytes32 internal constant UPGRADER_ROLE = keccak256("UPGRADER");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("GUARDIAN");

    // ============================================================
    // REENTRANCY GUARD
    // ============================================================

    /**
     * @notice Enter reentrancy guard
     * @param s Storage reference
     */
    function enterGuard(GiveProtocolStorage.AppStorage storage s) internal {
        if (s.reentrancyStatus == ENTERED) {
            revert ModuleBase__Reentrancy();
        }
        s.reentrancyStatus = ENTERED;
    }

    /**
     * @notice Exit reentrancy guard
     * @param s Storage reference
     */
    function exitGuard(GiveProtocolStorage.AppStorage storage s) internal {
        s.reentrancyStatus = NOT_ENTERED;
    }

    // ============================================================
    // ACCESS CONTROL
    // ============================================================

    /**
     * @notice Check if caller has required role
     * @param s Storage reference
     * @param caller Address to check
     * @param role Required role
     * @dev Reverts if caller doesn't have role
     */
    function requireRole(
        GiveProtocolStorage.AppStorage storage s,
        address caller,
        bytes32 role
    ) internal view {
        if (!hasRole(s, caller, role)) {
            revert ModuleBase__Unauthorized(caller, role);
        }
    }

    /**
     * @notice Check if address has role
     * @param s Storage reference
     * @param account Address to check
     * @param role Role to check
     * @return hasRole_ True if account has role
     */
    function hasRole(
        GiveProtocolStorage.AppStorage storage s,
        address account,
        bytes32 role
    ) internal view returns (bool) {
        // Call ACL Manager
        // For now, return true for DEFAULT_ADMIN_ROLE on aclManager
        // In production, implement: IACLManager(s.aclManager).hasRole(role, account)
        if (role == DEFAULT_ADMIN_ROLE && account == s.aclManager) {
            return true;
        }
        return false; // Placeholder - implement ACL Manager integration
    }

    // ============================================================
    // PAUSE CHECKS
    // ============================================================

    /**
     * @notice Require operation is not globally paused
     * @param s Storage reference
     */
    function requireNotGloballyPaused(
        GiveProtocolStorage.AppStorage storage s
    ) internal view {
        if (s.globalPaused) {
            revert ModuleBase__OperationPaused("GLOBAL");
        }
    }

    /**
     * @notice Require vault is not paused
     * @param s Storage reference
     * @param vault Vault address
     */
    function requireVaultNotPaused(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) internal view {
        if (s.vaultPaused[vault]) {
            revert ModuleBase__OperationPaused("VAULT");
        }
    }

    /**
     * @notice Require deposits are not paused
     * @param s Storage reference
     */
    function requireDepositNotPaused(
        GiveProtocolStorage.AppStorage storage s
    ) internal view {
        if (s.depositPaused) {
            revert ModuleBase__OperationPaused("DEPOSIT");
        }
    }

    /**
     * @notice Require withdrawals are not paused
     * @param s Storage reference
     */
    function requireWithdrawNotPaused(
        GiveProtocolStorage.AppStorage storage s
    ) internal view {
        if (s.withdrawPaused) {
            revert ModuleBase__OperationPaused("WITHDRAW");
        }
    }

    /**
     * @notice Require harvests are not paused
     * @param s Storage reference
     */
    function requireHarvestNotPaused(
        GiveProtocolStorage.AppStorage storage s
    ) internal view {
        if (s.harvestPaused) {
            revert ModuleBase__OperationPaused("HARVEST");
        }
    }

    /**
     * @notice Require campaign creation is not paused
     * @param s Storage reference
     */
    function requireCampaignCreationNotPaused(
        GiveProtocolStorage.AppStorage storage s
    ) internal view {
        if (s.campaignCreationPaused) {
            revert ModuleBase__OperationPaused("CAMPAIGN_CREATION");
        }
    }

    // ============================================================
    // VALIDATION HELPERS
    // ============================================================

    /**
     * @notice Validate address is not zero
     * @param addr Address to validate
     */
    function requireNonZeroAddress(address addr) internal pure {
        if (addr == address(0)) {
            revert ModuleBase__InvalidAddress(addr);
        }
    }

    /**
     * @notice Validate amount is not zero
     * @param amount Amount to validate
     */
    function requireNonZeroAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert ModuleBase__InvalidAmount(amount);
        }
    }

    /**
     * @notice Validate basis points
     * @param bps Basis points to validate
     * @param max Maximum allowed basis points
     */
    function requireValidBps(uint256 bps, uint256 max) internal pure {
        if (bps > max) {
            revert ModuleBase__InvalidBps(bps, max);
        }
    }

    /**
     * @notice Require vault exists
     * @param s Storage reference
     * @param vault Vault address
     */
    function requireVaultExists(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) internal view {
        if (!s.isVault[vault]) {
            revert ModuleBase__VaultNotFound(vault);
        }
    }

    /**
     * @notice Require adapter exists
     * @param s Storage reference
     * @param adapter Adapter address
     */
    function requireAdapterExists(
        GiveProtocolStorage.AppStorage storage s,
        address adapter
    ) internal view {
        if (!s.isAdapter[adapter]) {
            revert ModuleBase__AdapterNotFound(adapter);
        }
    }

    /**
     * @notice Require campaign exists
     * @param s Storage reference
     * @param campaignId Campaign ID
     */
    function requireCampaignExists(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) internal view {
        if (!s.isCampaign[campaignId]) {
            revert ModuleBase__CampaignNotFound(campaignId);
        }
    }

    /**
     * @notice Validate sufficient balance
     * @param available Available amount
     * @param required Required amount
     */
    function requireSufficientBalance(
        uint256 available,
        uint256 required
    ) internal pure {
        if (available < required) {
            revert ModuleBase__InsufficientBalance(available, required);
        }
    }

    // ============================================================
    // EVENT HELPERS
    // ============================================================

    /**
     * @notice Emit module action event
     * @param module Module name
     * @param action Action name
     * @param actor Address performing action
     * @param data Action data
     */
    function emitModuleAction(
        string memory module,
        string memory action,
        address actor,
        bytes memory data
    ) internal {
        emit ModuleAction(module, action, actor, data);
    }

    /**
     * @notice Emit pause state change event
     * @param context Pause context
     * @param isPaused New pause state
     * @param actor Address changing pause state
     */
    function emitPauseStateChanged(
        string memory context,
        bool isPaused,
        address actor
    ) internal {
        emit PauseStateChanged(context, isPaused, actor);
    }

    // ============================================================
    // MATH HELPERS
    // ============================================================

    /**
     * @notice Calculate basis points
     * @param amount Amount
     * @param bps Basis points
     * @return result Amount * bps / 10000
     */
    function calculateBps(
        uint256 amount,
        uint256 bps
    ) internal pure returns (uint256) {
        return (amount * bps) / DataTypes.BASIS_POINTS;
    }

    /**
     * @notice Calculate percentage with basis points
     * @param amount Amount
     * @param bps Basis points
     * @return result Amount * (10000 - bps) / 10000
     */
    function calculateAfterBps(
        uint256 amount,
        uint256 bps
    ) internal pure returns (uint256) {
        return (amount * (DataTypes.BASIS_POINTS - bps)) / DataTypes.BASIS_POINTS;
    }

    /**
     * @notice Safe min of two uint256
     * @param a First value
     * @param b Second value
     * @return result Minimum value
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Safe max of two uint256
     * @param a First value
     * @param b Second value
     * @return result Maximum value
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
