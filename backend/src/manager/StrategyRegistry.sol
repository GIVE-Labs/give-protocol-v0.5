// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {RoleAware} from "../access/RoleAware.sol";
import {Errors} from "../utils/Errors.sol";
import {RegistryTypes} from "./RegistryTypes.sol";

/// @title StrategyRegistry
/// @notice Catalog of yield strategies that campaigns can opt into.
contract StrategyRegistry is RoleAware, Pausable {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Strategy metadata stored on-chain.
    struct Strategy {
        uint64 id;
        address asset;
        address adapter;
        RegistryTypes.RiskTier riskTier;
        RegistryTypes.StrategyStatus status;
        string metadataURI;
        uint256 maxTvl;
        uint256 createdAt;
        uint256 updatedAt;
    }

    /// @dev Incremental id for newly created strategies.
    uint64 private _strategyIdCursor;

    /// @dev Mapping of strategy id to metadata.
    mapping(uint64 => Strategy) private _strategies;

    /// @dev Track existing strategy ids for enumeration.
    EnumerableSet.UintSet private _strategyIds;

    /// @dev Quick lookup to avoid duplicate asset/adapter pairs. Value is strategy id.
    mapping(address => mapping(address => uint64)) private _strategyIdByPair;

    /// @notice Cached role ids.
    bytes32 public immutable STRATEGY_ADMIN_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;

    /// @notice Emitted when a new strategy is registered.
    event StrategyCreated(
        uint64 indexed id,
        address indexed asset,
        address indexed adapter,
        RegistryTypes.RiskTier riskTier,
        string metadataURI,
        uint256 maxTvl
    );

    /// @notice Emitted when an existing strategy is updated.
    event StrategyUpdated(
        uint64 indexed id,
        address indexed asset,
        address indexed adapter,
        RegistryTypes.RiskTier riskTier,
        string metadataURI,
        uint256 maxTvl
    );

    /// @notice Emitted when a strategy status transitions.
    event StrategyStatusChanged(
        uint64 indexed id,
        RegistryTypes.StrategyStatus previousStatus,
        RegistryTypes.StrategyStatus newStatus,
        address indexed caller
    );

    /// @notice Emitted when a strategy's risk tier changes.
    event StrategyRiskTierChanged(
        uint64 indexed id, RegistryTypes.RiskTier previousTier, RegistryTypes.RiskTier newTier
    );

    /// @notice Emitted when registry pause state toggles.
    event RegistryPaused(address indexed caller);
    event RegistryUnpaused(address indexed caller);

    constructor(address roleManager_) RoleAware(roleManager_) {
        STRATEGY_ADMIN_ROLE = roleManager.ROLE_STRATEGY_ADMIN();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
    }

    /*//////////////////////////////////////////////////////////////
                                REGISTRY MUTATORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new strategy that campaigns can leverage.
    function createStrategy(
        address asset,
        address adapter,
        RegistryTypes.RiskTier riskTier,
        string calldata metadataURI,
        uint256 maxTvl
    ) external onlyRole(STRATEGY_ADMIN_ROLE) whenNotPaused returns (uint64 id) {
        if (asset == address(0) || adapter == address(0)) revert Errors.ZeroAddress();
        if (bytes(metadataURI).length == 0) revert Errors.InvalidMetadataCid();

        uint64 existing = _strategyIdByPair[asset][adapter];
        if (existing != 0) revert Errors.StrategyAlreadyExists();

        id = ++_strategyIdCursor;
        uint256 timestamp = block.timestamp;

        Strategy memory strategy = Strategy({
            id: id,
            asset: asset,
            adapter: adapter,
            riskTier: riskTier,
            status: RegistryTypes.StrategyStatus.Active,
            metadataURI: metadataURI,
            maxTvl: maxTvl,
            createdAt: timestamp,
            updatedAt: timestamp
        });

        _strategies[id] = strategy;
        _strategyIds.add(id);
        _strategyIdByPair[asset][adapter] = id;

        emit StrategyCreated(id, asset, adapter, riskTier, metadataURI, maxTvl);
    }

    /// @notice Updates adapter, metadata URI, risk tier, and max TVL for a strategy.
    function updateStrategy(
        uint64 id,
        address newAdapter,
        RegistryTypes.RiskTier newRiskTier,
        string calldata newMetadataURI,
        uint256 newMaxTvl
    ) external onlyRole(STRATEGY_ADMIN_ROLE) whenNotPaused {
        Strategy storage strategy = _strategies[id];
        if (strategy.id == 0) revert Errors.StrategyNotFound();

        if (bytes(newMetadataURI).length == 0) revert Errors.InvalidMetadataCid();
        if (newAdapter == address(0)) revert Errors.ZeroAddress();

        // Update adapter association if changed.
        if (strategy.adapter != newAdapter) {
            uint64 existing = _strategyIdByPair[strategy.asset][newAdapter];
            if (existing != 0) revert Errors.StrategyAlreadyExists();
            // Clear previous mapping and set new mapping
            delete _strategyIdByPair[strategy.asset][strategy.adapter];
            _strategyIdByPair[strategy.asset][newAdapter] = id;
            strategy.adapter = newAdapter;
        }

        if (strategy.riskTier != newRiskTier) {
            RegistryTypes.RiskTier previousTier = strategy.riskTier;
            strategy.riskTier = newRiskTier;
            emit StrategyRiskTierChanged(id, previousTier, newRiskTier);
        }

        strategy.metadataURI = newMetadataURI;
        strategy.maxTvl = newMaxTvl;
        strategy.updatedAt = block.timestamp;

        emit StrategyUpdated(id, strategy.asset, strategy.adapter, strategy.riskTier, newMetadataURI, newMaxTvl);
    }

    /// @notice Adjusts the status of a strategy (e.g., Active → FadingOut).
    function setStrategyStatus(uint64 id, RegistryTypes.StrategyStatus newStatus) external whenNotPaused {
        Strategy storage strategy = _strategies[id];
        if (strategy.id == 0) revert Errors.StrategyNotFound();
        if (strategy.status == newStatus) revert Errors.StatusTransitionInvalid();

        bool isStrategyAdmin = roleManager.hasRole(STRATEGY_ADMIN_ROLE, msg.sender);
        bool isGuardian = roleManager.hasRole(GUARDIAN_ROLE, msg.sender);

        if (!isStrategyAdmin) {
            // Guardians can only move Active → FadingOut/Deprecated, or FadingOut → Deprecated.
            if (!isGuardian) revert Errors.UnauthorizedManager();
            if (
                !(
                    newStatus == RegistryTypes.StrategyStatus.FadingOut
                        || newStatus == RegistryTypes.StrategyStatus.Deprecated
                )
            ) {
                revert Errors.OperationNotAllowed();
            }
        }

        RegistryTypes.StrategyStatus previous = strategy.status;
        strategy.status = newStatus;
        strategy.updatedAt = block.timestamp;

        emit StrategyStatusChanged(id, previous, newStatus, msg.sender);
    }

    /// @notice Sets the maximum target TVL (in underlying units) for a strategy.
    function setStrategyMaxTvl(uint64 id, uint256 newMaxTvl) external onlyRole(STRATEGY_ADMIN_ROLE) whenNotPaused {
        Strategy storage strategy = _strategies[id];
        if (strategy.id == 0) revert Errors.StrategyNotFound();
        strategy.maxTvl = newMaxTvl;
        strategy.updatedAt = block.timestamp;

        emit StrategyUpdated(id, strategy.asset, strategy.adapter, strategy.riskTier, strategy.metadataURI, newMaxTvl);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns a strategy by id.
    function getStrategy(uint64 id) external view returns (Strategy memory) {
        Strategy memory strategy = _strategies[id];
        if (strategy.id == 0) revert Errors.StrategyNotFound();
        return strategy;
    }

    /// @notice Convenience getter that returns the strategy id for an asset/adapter pair (or zero if none).
    function getStrategyId(address asset, address adapter) external view returns (uint64) {
        return _strategyIdByPair[asset][adapter];
    }

    /// @notice Returns the number of registered strategies.
    function strategyCount() external view returns (uint256) {
        return _strategyIds.length();
    }

    /// @notice Lists strategy ids with pagination support.
    function listStrategyIds(uint256 offset, uint256 limit) external view returns (uint64[] memory ids) {
        uint256 total = _strategyIds.length();
        if (offset >= total) return new uint64[](0);

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 resultLength = end - offset;
        ids = new uint64[](resultLength);
        for (uint256 i = 0; i < resultLength; ++i) {
            ids[i] = uint64(_strategyIds.at(offset + i));
        }
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSING
    //////////////////////////////////////////////////////////////*/

    /// @notice Guardian-only pause to stop registry modifications.
    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
        emit RegistryPaused(msg.sender);
    }

    /// @notice Guardian-only unpause.
    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
        emit RegistryUnpaused(msg.sender);
    }
}
