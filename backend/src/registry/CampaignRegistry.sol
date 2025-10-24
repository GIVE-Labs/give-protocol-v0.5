// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IACLManager.sol";
import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

interface IStrategyRegistry {
    function getStrategy(
        bytes32 strategyId
    ) external view returns (GiveTypes.StrategyConfig memory);
}

/// @title CampaignRegistry
/// @notice Tracks campaign lifecycle, curator assignments, payout configuration, and supporter stake bookkeeping.
contract CampaignRegistry is Initializable, UUPSUpgradeable {
    IACLManager public aclManager;
    address public strategyRegistry;
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    /// @notice Minimum duration (in seconds) a stake must exist before voting eligibility
    /// @dev Flash loan protection: Prevents flash loan attacks by requiring stake commitment
    uint64 public constant MIN_STAKE_DURATION = 1 hours;

    struct CampaignInput {
        bytes32 id;
        address payoutRecipient;
        bytes32 strategyId;
        bytes32 metadataHash;
        uint256 targetStake;
        uint256 minStake;
        uint64 fundraisingStart;
        uint64 fundraisingEnd;
    }

    struct CheckpointInput {
        uint64 windowStart;
        uint64 windowEnd;
        uint64 executionDeadline;
        uint16 quorumBps;
    }

    event CampaignSubmitted(
        bytes32 indexed id,
        address indexed proposer,
        bytes32 metadataHash
    );
    event CampaignApproved(bytes32 indexed id, address indexed curator);
    event CampaignStatusChanged(
        bytes32 indexed id,
        GiveTypes.CampaignStatus previousStatus,
        GiveTypes.CampaignStatus newStatus
    );
    event PayoutRecipientUpdated(
        bytes32 indexed id,
        address indexed previousRecipient,
        address indexed newRecipient
    );
    event StakeDeposited(
        bytes32 indexed id,
        address indexed supporter,
        uint256 amount,
        uint256 totalStaked
    );
    event StakeExitRequested(
        bytes32 indexed id,
        address indexed supporter,
        uint256 amountRequested
    );
    event StakeExitFinalized(
        bytes32 indexed id,
        address indexed supporter,
        uint256 amountWithdrawn,
        uint256 remainingStake
    );
    event LockedStakeUpdated(
        bytes32 indexed id,
        uint256 previousAmount,
        uint256 newAmount
    );
    event CampaignVaultRegistered(
        bytes32 indexed campaignId,
        address indexed vault,
        bytes32 lockProfile
    );
    event CheckpointScheduled(
        bytes32 indexed campaignId,
        uint256 index,
        uint64 start,
        uint64 end,
        uint16 quorumBps
    );
    event CheckpointStatusUpdated(
        bytes32 indexed campaignId,
        uint256 index,
        GiveTypes.CheckpointStatus previousStatus,
        GiveTypes.CheckpointStatus newStatus
    );
    event CheckpointVoteCast(
        bytes32 indexed campaignId,
        uint256 index,
        address indexed supporter,
        bool support,
        uint208 weight
    );
    event PayoutsHalted(bytes32 indexed campaignId, bool halted);

    error ZeroAddress();
    error Unauthorized(bytes32 roleId, address account);
    error CampaignAlreadyExists(bytes32 id);
    error CampaignNotFound(bytes32 id);
    error InvalidCampaignConfig(bytes32 id);
    error InvalidCampaignStatus(bytes32 id, GiveTypes.CampaignStatus status);
    error InvalidStakeAmount();
    error SupporterStakeMissing(address supporter);
    error CheckpointNotFound(bytes32 id, uint256 index);
    error InvalidCheckpointWindow();
    error InvalidCheckpointStatus(GiveTypes.CheckpointStatus status);
    error StrategyRegistryNotConfigured();
    error AlreadyVoted(address supporter);
    error NoVotingPower(address supporter);

    bytes32[] private _campaignIds;

    modifier onlyRole(bytes32 roleId) {
        if (!aclManager.hasRole(roleId, msg.sender)) {
            revert Unauthorized(roleId, msg.sender);
        }
        _;
    }

    function initialize(
        address acl,
        address strategyRegistry_
    ) external initializer {
        if (acl == address(0) || strategyRegistry_ == address(0))
            revert ZeroAddress();
        aclManager = IACLManager(acl);
        strategyRegistry = strategyRegistry_;
    }

    // === Campaign Lifecycle ===

    function submitCampaign(
        CampaignInput calldata input
    ) external onlyRole(aclManager.campaignCreatorRole()) {
        _validateCampaignInput(input);

        _fetchStrategy(input.strategyId, input.id);

        GiveTypes.CampaignConfig storage cfg = StorageLib.campaign(input.id);
        if (cfg.exists) revert CampaignAlreadyExists(input.id);

        cfg.id = input.id;
        cfg.proposer = msg.sender;
        cfg.payoutRecipient = input.payoutRecipient;
        cfg.strategyId = input.strategyId;
        cfg.metadataHash = input.metadataHash;
        cfg.targetStake = input.targetStake;
        cfg.minStake = input.minStake;
        cfg.fundraisingStart = input.fundraisingStart;
        cfg.fundraisingEnd = input.fundraisingEnd;
        cfg.createdAt = uint64(block.timestamp);
        cfg.updatedAt = uint64(block.timestamp);
        cfg.status = GiveTypes.CampaignStatus.Submitted;
        cfg.exists = true;

        _campaignIds.push(input.id);

        emit CampaignSubmitted(input.id, msg.sender, input.metadataHash);
    }

    function approveCampaign(
        bytes32 campaignId,
        address curator
    ) external onlyRole(aclManager.campaignAdminRole()) {
        if (curator == address(0)) revert ZeroAddress();

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        if (cfg.status != GiveTypes.CampaignStatus.Submitted) {
            revert InvalidCampaignStatus(campaignId, cfg.status);
        }

        cfg.curator = curator;
        cfg.status = GiveTypes.CampaignStatus.Approved;
        cfg.updatedAt = uint64(block.timestamp);

        emit CampaignApproved(campaignId, curator);
        emit CampaignStatusChanged(
            campaignId,
            GiveTypes.CampaignStatus.Submitted,
            GiveTypes.CampaignStatus.Approved
        );
    }

    function setCampaignStatus(
        bytes32 campaignId,
        GiveTypes.CampaignStatus newStatus
    ) external onlyRole(aclManager.campaignAdminRole()) {
        if (newStatus == GiveTypes.CampaignStatus.Unknown) {
            revert InvalidCampaignStatus(campaignId, newStatus);
        }

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        GiveTypes.CampaignStatus previous = cfg.status;
        if (previous == newStatus) return;

        cfg.status = newStatus;
        cfg.updatedAt = uint64(block.timestamp);

        emit CampaignStatusChanged(campaignId, previous, newStatus);
    }

    function setPayoutRecipient(
        bytes32 campaignId,
        address recipient
    ) external onlyRole(aclManager.campaignAdminRole()) {
        if (recipient == address(0)) revert ZeroAddress();

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        address previous = cfg.payoutRecipient;
        cfg.payoutRecipient = recipient;
        cfg.updatedAt = uint64(block.timestamp);

        emit PayoutRecipientUpdated(campaignId, previous, recipient);
    }

    function setCampaignVault(
        bytes32 campaignId,
        address vault,
        bytes32 lockProfile
    ) external onlyRole(aclManager.campaignAdminRole()) {
        if (vault == address(0)) revert ZeroAddress();

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        cfg.vault = vault;
        cfg.lockProfile = lockProfile;
        cfg.updatedAt = uint64(block.timestamp);

        StorageLib.setVaultCampaign(vault, campaignId);

        emit CampaignVaultRegistered(campaignId, vault, lockProfile);
    }

    function setStrategyRegistry(
        address newRegistry
    ) external onlyRole(aclManager.campaignAdminRole()) {
        if (newRegistry == address(0)) revert ZeroAddress();
        strategyRegistry = newRegistry;
    }

    function updateLockedStake(
        bytes32 campaignId,
        uint256 lockedAmount
    ) external onlyRole(aclManager.campaignAdminRole()) {
        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        uint256 previous = cfg.lockedStake;
        cfg.lockedStake = lockedAmount;
        cfg.updatedAt = uint64(block.timestamp);

        emit LockedStakeUpdated(campaignId, previous, lockedAmount);
    }

    // === Stake Escrow ===

    function recordStakeDeposit(
        bytes32 campaignId,
        address supporter,
        uint256 amount
    ) external onlyRole(aclManager.campaignCuratorRole()) {
        if (supporter == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidStakeAmount();

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        if (
            cfg.status == GiveTypes.CampaignStatus.Cancelled ||
            cfg.status == GiveTypes.CampaignStatus.Completed ||
            cfg.status == GiveTypes.CampaignStatus.Unknown
        ) {
            revert InvalidCampaignStatus(campaignId, cfg.status);
        }

        GiveTypes.CampaignStakeState storage stakeState = StorageLib
            .campaignStake(campaignId);
        GiveTypes.SupporterStake storage stake = stakeState.supporterStake[
            supporter
        ];

        if (!stake.exists) {
            stakeState.supporters.push(supporter);
            stake.exists = true;
            stake.lastUpdated = uint64(block.timestamp);
            // Flash loan protection: Record initial stake timestamp
            // Must be staked for MIN_STAKE_DURATION before voting eligibility
            stake.stakeTimestamp = uint64(block.timestamp);
        }

        stake.shares += amount;
        stake.lastUpdated = uint64(block.timestamp);
        stake.requestedExit = false;

        stakeState.totalActive += amount;
        cfg.totalStaked += amount;
        cfg.updatedAt = uint64(block.timestamp);

        emit StakeDeposited(campaignId, supporter, amount, cfg.totalStaked);
    }

    function requestStakeExit(
        bytes32 campaignId,
        address supporter,
        uint256 amount
    ) external onlyRole(aclManager.campaignCuratorRole()) {
        if (supporter == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidStakeAmount();

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        if (
            cfg.status == GiveTypes.CampaignStatus.Cancelled ||
            cfg.status == GiveTypes.CampaignStatus.Completed
        ) {
            revert InvalidCampaignStatus(campaignId, cfg.status);
        }

        GiveTypes.CampaignStakeState storage stakeState = StorageLib
            .campaignStake(campaignId);
        GiveTypes.SupporterStake storage stake = stakeState.supporterStake[
            supporter
        ];
        if (!stake.exists || stake.shares < amount)
            revert SupporterStakeMissing(supporter);

        stake.shares -= amount;
        stake.pendingWithdrawal += amount;
        stake.lastUpdated = uint64(block.timestamp);
        stake.requestedExit = true;

        stakeState.totalActive -= amount;
        stakeState.totalPendingExit += amount;

        emit StakeExitRequested(campaignId, supporter, amount);
    }

    function finalizeStakeExit(
        bytes32 campaignId,
        address supporter,
        uint256 amount
    ) external onlyRole(aclManager.campaignAdminRole()) {
        if (supporter == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidStakeAmount();

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        GiveTypes.CampaignStakeState storage stakeState = StorageLib
            .campaignStake(campaignId);
        GiveTypes.SupporterStake storage stake = stakeState.supporterStake[
            supporter
        ];
        if (!stake.exists || stake.pendingWithdrawal < amount)
            revert SupporterStakeMissing(supporter);

        stake.pendingWithdrawal -= amount;
        stake.lastUpdated = uint64(block.timestamp);
        if (stake.pendingWithdrawal == 0) {
            stake.requestedExit = false;
        }

        if (stake.shares == 0 && stake.pendingWithdrawal == 0) {
            stake.exists = false;
        }

        if (stakeState.totalPendingExit < amount) {
            stakeState.totalPendingExit = 0;
        } else {
            stakeState.totalPendingExit -= amount;
        }

        if (cfg.totalStaked < amount) {
            cfg.totalStaked = 0;
        } else {
            cfg.totalStaked -= amount;
        }

        cfg.updatedAt = uint64(block.timestamp);

        emit StakeExitFinalized(campaignId, supporter, amount, stake.shares);
    }

    // === Checkpoints ===

    function scheduleCheckpoint(
        bytes32 campaignId,
        CheckpointInput calldata input
    )
        external
        onlyRole(aclManager.campaignAdminRole())
        returns (uint256 index)
    {
        if (
            input.windowStart == 0 ||
            input.windowEnd <= input.windowStart ||
            input.executionDeadline < input.windowEnd
        ) {
            revert InvalidCheckpointWindow();
        }
        if (input.quorumBps == 0 || input.quorumBps > 10_000) {
            revert InvalidCheckpointWindow();
        }

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        GiveTypes.CampaignCheckpointState storage cpState = StorageLib
            .campaignCheckpoints(campaignId);

        index = cpState.nextIndex;
        cpState.nextIndex += 1;

        GiveTypes.CampaignCheckpoint storage checkpoint = cpState.checkpoints[
            index
        ];
        checkpoint.index = index;
        checkpoint.windowStart = input.windowStart;
        checkpoint.windowEnd = input.windowEnd;
        checkpoint.executionDeadline = input.executionDeadline;
        checkpoint.quorumBps = input.quorumBps;
        checkpoint.status = GiveTypes.CheckpointStatus.Scheduled;
        checkpoint.totalEligibleVotes = uint208(cfg.totalStaked);
        checkpoint.startBlock = uint32(block.number);
        checkpoint.votingStartsAt = input.windowStart;
        checkpoint.votingEndsAt = input.windowEnd;

        emit CheckpointScheduled(
            campaignId,
            index,
            input.windowStart,
            input.windowEnd,
            input.quorumBps
        );
    }

    function updateCheckpointStatus(
        bytes32 campaignId,
        uint256 index,
        GiveTypes.CheckpointStatus newStatus
    ) external onlyRole(aclManager.checkpointCouncilRole()) {
        if (newStatus == GiveTypes.CheckpointStatus.None)
            revert InvalidCheckpointStatus(newStatus);

        GiveTypes.CampaignCheckpointState storage cpState = StorageLib
            .campaignCheckpoints(campaignId);
        GiveTypes.CampaignCheckpoint storage checkpoint = cpState.checkpoints[
            index
        ];
        if (checkpoint.windowStart == 0)
            revert CheckpointNotFound(campaignId, index);

        GiveTypes.CheckpointStatus previous = checkpoint.status;
        if (previous == newStatus) return;

        checkpoint.status = newStatus;

        if (newStatus == GiveTypes.CheckpointStatus.Voting) {
            checkpoint.startBlock = uint32(block.number);
            // Flash loan protection: Capture snapshot block for voting power calculation
            // Voting power will be based on stakes at this block, not current balance
            checkpoint.snapshotBlock = uint32(block.number);
        }

        if (
            newStatus == GiveTypes.CheckpointStatus.Succeeded ||
            newStatus == GiveTypes.CheckpointStatus.Failed
        ) {
            checkpoint.endBlock = uint32(block.number);
        }

        emit CheckpointStatusUpdated(campaignId, index, previous, newStatus);
        if (newStatus == GiveTypes.CheckpointStatus.Failed) {
            GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
            cfg.payoutsHalted = true;
            emit PayoutsHalted(campaignId, true);
        }
    }

    function voteOnCheckpoint(
        bytes32 campaignId,
        uint256 index,
        bool support
    ) external {
        GiveTypes.CampaignCheckpointState storage cpState = StorageLib
            .campaignCheckpoints(campaignId);
        GiveTypes.CampaignCheckpoint storage checkpoint = cpState.checkpoints[
            index
        ];
        if (checkpoint.status != GiveTypes.CheckpointStatus.Voting)
            revert InvalidCheckpointStatus(checkpoint.status);
        if (
            block.timestamp < checkpoint.votingStartsAt ||
            block.timestamp > checkpoint.votingEndsAt
        ) {
            revert InvalidCheckpointWindow();
        }
        if (checkpoint.hasVoted[msg.sender]) revert AlreadyVoted(msg.sender);

        GiveTypes.CampaignStakeState storage stakeState = StorageLib
            .campaignStake(campaignId);
        GiveTypes.SupporterStake storage stake = stakeState.supporterStake[
            msg.sender
        ];
        if (!stake.exists || stake.shares == 0)
            revert NoVotingPower(msg.sender);

        // Flash loan protection: Enforce minimum stake duration
        // Voter must have staked for at least MIN_STAKE_DURATION before voting eligibility
        if (block.timestamp < stake.stakeTimestamp + MIN_STAKE_DURATION) {
            revert NoVotingPower(msg.sender);
        }

        uint208 weight = uint208(stake.shares);
        checkpoint.hasVoted[msg.sender] = true;
        checkpoint.votedFor[msg.sender] = support;

        if (support) {
            checkpoint.votesFor += weight;
        } else {
            checkpoint.votesAgainst += weight;
        }

        emit CheckpointVoteCast(campaignId, index, msg.sender, support, weight);
    }

    function finalizeCheckpoint(
        bytes32 campaignId,
        uint256 index
    ) external onlyRole(aclManager.campaignAdminRole()) {
        GiveTypes.CampaignCheckpointState storage cpState = StorageLib
            .campaignCheckpoints(campaignId);
        GiveTypes.CampaignCheckpoint storage checkpoint = cpState.checkpoints[
            index
        ];
        if (checkpoint.status != GiveTypes.CheckpointStatus.Voting)
            revert InvalidCheckpointStatus(checkpoint.status);
        if (block.timestamp <= checkpoint.votingEndsAt)
            revert InvalidCheckpointWindow();

        uint208 totalVotesCast = checkpoint.votesFor + checkpoint.votesAgainst;
        if (checkpoint.totalEligibleVotes == 0) {
            GiveTypes.CampaignStakeState storage stakeState = StorageLib
                .campaignStake(campaignId);
            checkpoint.totalEligibleVotes = uint208(stakeState.totalActive);
        }

        bool quorumMet = checkpoint.totalEligibleVotes == 0
            ? true
            : totalVotesCast >=
                (uint208(checkpoint.quorumBps) *
                    checkpoint.totalEligibleVotes) /
                    10_000;

        GiveTypes.CheckpointStatus result = quorumMet &&
            checkpoint.votesFor > checkpoint.votesAgainst
            ? GiveTypes.CheckpointStatus.Succeeded
            : GiveTypes.CheckpointStatus.Failed;

        checkpoint.status = result;
        checkpoint.endBlock = uint32(block.number);

        emit CheckpointStatusUpdated(
            campaignId,
            index,
            GiveTypes.CheckpointStatus.Voting,
            result
        );

        GiveTypes.CampaignConfig storage cfg = _requireCampaign(campaignId);
        if (result == GiveTypes.CheckpointStatus.Failed) {
            cfg.payoutsHalted = true;
            cfg.status = GiveTypes.CampaignStatus.Paused;
            emit PayoutsHalted(campaignId, true);
        } else {
            if (cfg.payoutsHalted) {
                cfg.payoutsHalted = false;
                emit PayoutsHalted(campaignId, false);
            }
        }
    }

    // === Views ===

    function getCampaign(
        bytes32 campaignId
    ) external view returns (GiveTypes.CampaignConfig memory) {
        GiveTypes.CampaignConfig storage cfg = StorageLib.campaign(campaignId);
        if (!cfg.exists) revert CampaignNotFound(campaignId);
        return cfg;
    }

    function getCampaignByVault(
        address vault
    ) external view returns (GiveTypes.CampaignConfig memory) {
        bytes32 campaignId = StorageLib.getVaultCampaign(vault);
        if (campaignId == bytes32(0)) revert CampaignNotFound(bytes32(0));
        return StorageLib.campaign(campaignId);
    }

    function listCampaignIds() external view returns (bytes32[] memory) {
        return _campaignIds;
    }

    function getStakePosition(
        bytes32 campaignId,
        address supporter
    ) external view returns (GiveTypes.SupporterStake memory) {
        GiveTypes.CampaignStakeState storage stakeState = StorageLib
            .campaignStake(campaignId);
        return stakeState.supporterStake[supporter];
    }

    function getCheckpoint(
        bytes32 campaignId,
        uint256 index
    )
        external
        view
        returns (
            uint64 windowStart,
            uint64 windowEnd,
            uint64 executionDeadline,
            uint16 quorumBps,
            GiveTypes.CheckpointStatus status,
            uint256 totalEligibleStake
        )
    {
        GiveTypes.CampaignCheckpointState storage cpState = StorageLib
            .campaignCheckpoints(campaignId);
        GiveTypes.CampaignCheckpoint storage checkpoint = cpState.checkpoints[
            index
        ];
        if (checkpoint.windowStart == 0)
            revert CheckpointNotFound(campaignId, index);

        return (
            checkpoint.windowStart,
            checkpoint.windowEnd,
            checkpoint.executionDeadline,
            checkpoint.quorumBps,
            checkpoint.status,
            uint256(checkpoint.totalEligibleVotes)
        );
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Unauthorized(ROLE_UPGRADER, msg.sender);
        }
    }

    function _validateCampaignInput(CampaignInput calldata input) private pure {
        if (
            input.id == bytes32(0) ||
            input.payoutRecipient == address(0) ||
            input.strategyId == bytes32(0) ||
            input.targetStake == 0 ||
            input.minStake > input.targetStake
        ) {
            revert InvalidCampaignConfig(input.id);
        }
        if (
            input.fundraisingEnd != 0 &&
            input.fundraisingEnd <= input.fundraisingStart
        ) {
            revert InvalidCampaignConfig(input.id);
        }
    }

    function _requireCampaign(
        bytes32 campaignId
    ) private view returns (GiveTypes.CampaignConfig storage cfg) {
        cfg = StorageLib.campaign(campaignId);
        if (!cfg.exists) revert CampaignNotFound(campaignId);
    }

    function _fetchStrategy(
        bytes32 strategyId,
        bytes32 campaignId
    ) private view returns (GiveTypes.StrategyConfig memory strategyCfg) {
        address registry = strategyRegistry;
        if (registry == address(0)) revert StrategyRegistryNotConfigured();

        try IStrategyRegistry(registry).getStrategy(strategyId) returns (
            GiveTypes.StrategyConfig memory cfg
        ) {
            if (
                !cfg.exists || cfg.status == GiveTypes.StrategyStatus.Deprecated
            ) {
                revert InvalidCampaignConfig(campaignId);
            }
            strategyCfg = cfg;
        } catch {
            revert InvalidCampaignConfig(campaignId);
        }
    }
}
