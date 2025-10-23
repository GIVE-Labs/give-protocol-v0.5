// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IACLManager.sol";
import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

/// @title StrategyRegistry
/// @notice Canonical registry for protocol strategies and their lifecycle state.
contract StrategyRegistry is Initializable, UUPSUpgradeable {
    IACLManager public aclManager;

    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    struct StrategyInput {
        bytes32 id;
        address adapter;
        bytes32 riskTier;
        uint256 maxTvl;
        bytes32 metadataHash;
    }

    event StrategyRegistered(
        bytes32 indexed id, address indexed adapter, bytes32 riskTier, uint256 maxTvl, bytes32 metadataHash
    );
    event StrategyUpdated(
        bytes32 indexed id, address indexed adapter, bytes32 riskTier, uint256 maxTvl, bytes32 metadataHash
    );
    event StrategyStatusChanged(
        bytes32 indexed id, GiveTypes.StrategyStatus previousStatus, GiveTypes.StrategyStatus newStatus
    );
    event StrategyVaultLinked(bytes32 indexed strategyId, address indexed vault);

    error ZeroAddress();
    error Unauthorized(bytes32 roleId, address account);
    error StrategyAlreadyExists(bytes32 id);
    error StrategyNotFound(bytes32 id);
    error InvalidStrategyConfig(bytes32 id);

    bytes32[] private _strategyIds;

    modifier onlyRole(bytes32 roleId) {
        if (!aclManager.hasRole(roleId, msg.sender)) {
            revert Unauthorized(roleId, msg.sender);
        }
        _;
    }

    function initialize(address acl) external initializer {
        if (acl == address(0)) revert ZeroAddress();
        aclManager = IACLManager(acl);
    }

    function registerStrategy(StrategyInput calldata input) external onlyRole(aclManager.strategyAdminRole()) {
        if (input.id == bytes32(0) || input.adapter == address(0) || input.maxTvl == 0) {
            revert InvalidStrategyConfig(input.id);
        }

        GiveTypes.StrategyConfig storage cfg = StorageLib.strategy(input.id);
        if (cfg.exists) revert StrategyAlreadyExists(input.id);

        cfg.id = input.id;
        cfg.adapter = input.adapter;
        cfg.creator = msg.sender;
        cfg.metadataHash = input.metadataHash;
        cfg.riskTier = input.riskTier;
        cfg.maxTvl = input.maxTvl;
        cfg.createdAt = uint64(block.timestamp);
        cfg.updatedAt = uint64(block.timestamp);
        cfg.status = GiveTypes.StrategyStatus.Active;
        cfg.exists = true;

        _strategyIds.push(input.id);

        emit StrategyRegistered(input.id, input.adapter, input.riskTier, input.maxTvl, input.metadataHash);
    }

    function updateStrategy(StrategyInput calldata input) external onlyRole(aclManager.strategyAdminRole()) {
        if (input.id == bytes32(0) || input.adapter == address(0) || input.maxTvl == 0) {
            revert InvalidStrategyConfig(input.id);
        }

        GiveTypes.StrategyConfig storage cfg = StorageLib.strategy(input.id);
        if (!cfg.exists) revert StrategyNotFound(input.id);

        cfg.adapter = input.adapter;
        cfg.metadataHash = input.metadataHash;
        cfg.riskTier = input.riskTier;
        cfg.maxTvl = input.maxTvl;
        cfg.updatedAt = uint64(block.timestamp);

        emit StrategyUpdated(input.id, input.adapter, input.riskTier, input.maxTvl, input.metadataHash);
    }

    function setStrategyStatus(bytes32 strategyId, GiveTypes.StrategyStatus newStatus)
        external
        onlyRole(aclManager.strategyAdminRole())
    {
        if (newStatus == GiveTypes.StrategyStatus.Unknown) {
            revert InvalidStrategyConfig(strategyId);
        }

        GiveTypes.StrategyConfig storage cfg = StorageLib.strategy(strategyId);
        if (!cfg.exists) revert StrategyNotFound(strategyId);
        GiveTypes.StrategyStatus previous = cfg.status;
        if (previous == newStatus) return;

        cfg.status = newStatus;
        cfg.updatedAt = uint64(block.timestamp);

        emit StrategyStatusChanged(strategyId, previous, newStatus);
    }

    function getStrategy(bytes32 strategyId) external view returns (GiveTypes.StrategyConfig memory) {
        GiveTypes.StrategyConfig storage cfg = StorageLib.strategy(strategyId);
        if (!cfg.exists) revert StrategyNotFound(strategyId);
        return cfg;
    }

    function listStrategyIds() external view returns (bytes32[] memory) {
        return _strategyIds;
    }

    function registerStrategyVault(bytes32 strategyId, address vault)
        external
        onlyRole(aclManager.strategyAdminRole())
    {
        if (vault == address(0)) revert ZeroAddress();
        GiveTypes.StrategyConfig storage cfg = StorageLib.strategy(strategyId);
        if (!cfg.exists) revert StrategyNotFound(strategyId);

        address[] storage vaults = StorageLib.strategyVaults(strategyId);
        vaults.push(vault);

        emit StrategyVaultLinked(strategyId, vault);
    }

    function getStrategyVaults(bytes32 strategyId) external view returns (address[] memory) {
        address[] storage vaults = StorageLib.strategyVaults(strategyId);
        address[] memory copy = new address[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            copy[i] = vaults[i];
        }
        return copy;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Unauthorized(ROLE_UPGRADER, msg.sender);
        }
    }
}
