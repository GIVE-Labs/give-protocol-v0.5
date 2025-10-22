// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title GiveTypes
/// @notice Canonical data definitions shared across the GIVE Protocol architecture.
library GiveTypes {
    /// @dev Enumerates adapter behaviours so modules can apply the right accounting logic.
    enum AdapterKind {
        Unknown,
        CompoundingValue,
        ClaimableYield,
        BalanceGrowth,
        PerpetualYieldToken
    }

    /// @dev Tracks global protocol wiring information.
    struct SystemConfig {
        address aclManager;
        address upgrader; // address trusted to perform UUPS upgrades
        address bootstrapper;
        uint64 version;
        uint64 lastBootstrapAt;
        bool initialized;
    }

    /// @dev Describes vault-level parameters that modules operate against.
    struct VaultConfig {
        bytes32 id;
        address proxy;
        address implementation;
        address asset;
        bytes32 adapterId;
        bytes32 donationModuleId;
        address activeAdapter;
        address donationRouter;
        address wrappedNative;
        uint16 cashBufferBps;
        uint16 slippageBps;
        uint16 maxLossBps;
        uint256 lastHarvestTime;
        uint256 totalProfit;
        uint256 totalLoss;
        bool investPaused;
        bool harvestPaused;
        bool active;
    }

    /// @dev Captures metadata about supported assets.
    struct AssetConfig {
        bytes32 id;
        address token;
        uint8 decimals;
        bytes32 riskTier;
        address oracle;
        bool enabled;
    }

    /// @dev Stores adapter wiring and behaviour flags.
    struct AdapterConfig {
        bytes32 id;
        address proxy;
        address implementation;
        address asset;
        address vault;
        AdapterKind kind;
        bytes32 vaultId;
        bytes32 metadataHash;
        bool active;
    }

    struct SyntheticAsset {
        bytes32 id;
        address proxy;
        address asset;
        uint256 totalSupply;
        bool active;
        mapping(address => uint256) balances;
    }

    /// @dev Versioned risk parameters applied per vault or asset grouping.
    struct RiskConfig {
        bytes32 id;
        uint64 createdAt;
        uint64 updatedAt;
        uint16 ltvBps;
        uint16 liquidationThresholdBps;
        uint16 liquidationPenaltyBps;
        uint16 borrowCapBps;
        uint16 depositCapBps;
        bytes32 dataHash; // arbitrary encoded risk parameters for extensions
    }

    /// @dev Tracks user position state for enumerability and analytics.
    struct PositionState {
        bytes32 id;
        address owner;
        bytes32 vaultId;
        uint256 principal;
        uint256 shares;
        uint256 normalizedDebtIndex;
        uint256 lastAccrued; // timestamp
    }

    /// @dev Standard callback payload when adapters/modules need cross-communication.
    struct CallbackPayload {
        bytes32 sourceId;
        bytes32 targetId;
        bytes data;
    }

    /// @dev Represents role metadata stored by the ACL manager.
    struct RoleAssignments {
        bytes32 roleId;
        address admin;
        address pendingAdmin;
        bool exists;
        uint64 createdAt;
        uint64 updatedAt;
        address[] memberList;
        mapping(address => bool) isMember;
        mapping(address => uint256) memberIndex; // index + 1 for swap-and-pop
    }

    struct UserPreference {
        address selectedNGO;
        uint8 allocationPercentage;
        uint256 lastUpdated;
    }

    struct DonationRouterState {
        address registry;
        address feeRecipient;
        address protocolTreasury;
        uint256 feeBps;
        uint256 totalDistributions;
        uint256 totalNGOsSupported;
        mapping(address => UserPreference) userPreferences;
        mapping(address => mapping(address => uint256)) userAssetShares;
        mapping(address => uint256) totalAssetShares;
        mapping(address => address[]) usersWithShares;
        mapping(address => mapping(address => bool)) hasShares;
        mapping(address => uint256) totalDonated;
        mapping(address => uint256) totalFeeCollected;
        mapping(address => uint256) totalProtocolFees;
        mapping(address => bool) authorizedCallers;
        uint8[3] validAllocations;
    }

    struct NGOInfo {
        string metadataCid;
        bytes32 kycHash;
        address attestor;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 version;
        uint256 totalReceived;
        bool isActive;
    }

    struct NGORegistryState {
        mapping(address => bool) isApproved;
        mapping(address => NGOInfo) ngoInfo;
        address[] approvedNGOs;
        address currentNGO;
        address pendingCurrentNGO;
        uint256 currentNGOChangeETA;
    }
}
