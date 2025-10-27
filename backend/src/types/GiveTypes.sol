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
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }

    /// @dev Describes vault-level parameters that modules operate against.
    struct VaultConfig {
        bytes32 id;
        address proxy;
        address implementation;
        address asset;
        bytes32 adapterId;
        bytes32 donationModuleId;
        bytes32 riskId;
        address activeAdapter;
        address donationRouter;
        address wrappedNative;
        uint16 cashBufferBps;
        uint16 slippageBps;
        uint16 maxLossBps;
        uint256 lastHarvestTime;
        uint256 totalProfit;
        uint256 totalLoss;
        uint256 maxVaultDeposit;
        uint256 maxVaultBorrow;
        bool emergencyShutdown;
        uint64 emergencyActivatedAt;
        bool investPaused;
        bool harvestPaused;
        bool active;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }

    /// @dev Captures metadata about supported assets.
    struct AssetConfig {
        bytes32 id;
        address token;
        uint8 decimals;
        bytes32 riskTier;
        address oracle;
        bool enabled;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
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
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }

    struct SyntheticAsset {
        bytes32 id;
        address proxy;
        address asset;
        uint256 totalSupply;
        bool active;
        mapping(address => uint256) balances;
    }
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

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
        uint64 version;
        uint256 maxDeposit;
        uint256 maxBorrow;
        bool exists;
        bool active;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
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
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
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
        // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
        // Future fields must be appended carefully, maintaining backward compatibility.
    }

    struct UserPreference {
        address selectedNGO;
        uint8 allocationPercentage;
        uint256 lastUpdated;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }

    struct CampaignPreference {
        bytes32 campaignId;
        address beneficiary;
        uint8 allocationPercentage;
        uint256 lastUpdated;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
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
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

    struct PayoutRouterState {
        address campaignRegistry;
        address feeRecipient;
        address protocolTreasury;
        uint256 feeBps;
        uint256 totalDistributions;
        mapping(address => bool) authorizedCallers;
        mapping(address => mapping(address => uint256)) userVaultShares;
        mapping(address => uint256) totalVaultShares;
        mapping(address => address[]) vaultShareholders;
        mapping(address => mapping(address => bool)) hasVaultShare;
        mapping(address => mapping(address => CampaignPreference)) userPreferences;
        mapping(bytes32 => uint256) campaignProtocolFees;
        mapping(bytes32 => uint256) campaignTotalPayouts;
        mapping(address => bytes32) vaultCampaigns;
        uint8[3] validAllocations;
        mapping(uint256 => PendingFeeChange) pendingFeeChanges;
        uint256 feeChangeNonce;
    }
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

    /// @notice Pending fee change with timelock
    struct PendingFeeChange {
        uint256 newFeeBps;
        address newRecipient;
        uint256 effectiveTimestamp;
        bool exists;
        // Storage gap: Reserve slots for future upgrades
        uint256[50] __gap;
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
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }

    struct NGORegistryState {
        mapping(address => bool) isApproved;
        mapping(address => NGOInfo) ngoInfo;
        address[] approvedNGOs;
        address currentNGO;
        address pendingCurrentNGO;
        uint256 currentNGOChangeETA;
    }
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

    enum StrategyStatus {
        Unknown,
        Active,
        FadingOut,
        Deprecated
    }

    struct StrategyConfig {
        bytes32 id;
        address adapter;
        address creator;
        bytes32 metadataHash;
        bytes32 riskTier;
        uint256 maxTvl;
        uint64 createdAt;
        uint64 updatedAt;
        StrategyStatus status;
        bool exists;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }

    enum CampaignStatus {
        Unknown,
        Submitted,
        Approved,
        Active,
        Paused,
        Completed,
        Cancelled
    }

    struct CampaignConfig {
        bytes32 id;
        address proposer;
        address curator;
        address payoutRecipient;
        address vault;
        bytes32 strategyId;
        bytes32 metadataHash;
        uint256 targetStake;
        uint256 minStake;
        uint256 totalStaked;
        uint256 lockedStake;
        uint256 initialDeposit;
        uint64 fundraisingStart;
        uint64 fundraisingEnd;
        uint64 createdAt;
        uint64 updatedAt;
        CampaignStatus status;
        bytes32 lockProfile;
        uint16 checkpointQuorumBps;
        uint64 checkpointVotingDelay;
        uint64 checkpointVotingPeriod;
        bool exists;
        bool payoutsHalted;
        // Storage gap: Reserve slots for future upgrades (49 slots remaining after initialDeposit)
        uint256[49] __gap;
    }

    struct SupporterStake {
        uint256 shares;
        uint256 escrow;
        uint256 pendingWithdrawal;
        uint64 lockedUntil;
        uint64 lastUpdated;
        bool requestedExit;
        bool exists;
        // Flash loan protection: Timestamp when stake was first deposited
        // Must be staked for MIN_STAKE_DURATION before voting eligibility
        uint64 stakeTimestamp;
        // Storage gap: Reserve slots for future upgrades (49 slots remaining after stakeTimestamp)
        uint256[49] __gap;
    }

    struct CampaignStakeState {
        uint256 totalActive;
        uint256 totalPendingExit;
        address[] supporters;
        mapping(address => SupporterStake) supporterStake;
    }
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

    enum CheckpointStatus {
        None,
        Scheduled,
        Voting,
        Succeeded,
        Failed,
        Executed,
        Canceled
    }

    struct CampaignCheckpoint {
        uint256 index;
        uint64 windowStart;
        uint64 windowEnd;
        uint64 executionDeadline;
        uint16 quorumBps;
        CheckpointStatus status;
        uint32 startBlock;
        uint32 endBlock;
        uint64 votingStartsAt;
        uint64 votingEndsAt;
        uint208 votesFor;
        uint208 votesAgainst;
        uint208 totalEligibleVotes;
        bool executed;
        // Flash loan protection: Snapshot block when checkpoint voting starts
        // Voting power is calculated based on stakes at this block, not current balance
        uint32 snapshotBlock;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votedFor;
    }
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

    struct CampaignCheckpointState {
        uint256 nextIndex;
        mapping(uint256 => CampaignCheckpoint) checkpoints;
    }
    // NOTE: Structs with mappings cannot have storage gaps due to Solidity restrictions.
    // Future fields must be appended carefully, maintaining backward compatibility.

    struct CampaignVaultMeta {
        bytes32 id;
        bytes32 campaignId;
        bytes32 strategyId;
        bytes32 lockProfile;
        address factory;
        bool exists;
        // Storage gap: Reserve slots for future upgrades (50 slots = ~1600 bytes)
        uint256[50] __gap;
    }
}
