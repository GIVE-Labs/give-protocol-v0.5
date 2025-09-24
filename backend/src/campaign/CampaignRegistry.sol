// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {RoleAware} from "../access/RoleAware.sol";
import {Errors} from "../utils/Errors.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {StrategyRegistry} from "../manager/StrategyRegistry.sol";

/// @title CampaignRegistry
/// @notice Permissionless registry for campaign submissions, approvals, and strategy attachments.
contract CampaignRegistry is RoleAware, Pausable {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Campaign metadata tracked on-chain.
    struct Campaign {
        uint64 id;
        address creator;
        address curator;
        address payout;
        RegistryTypes.LockProfile defaultLock;
        RegistryTypes.CampaignStatus status;
        string metadataURI;
        uint96 stake;
        bool stakeRefunded;
        uint256 createdAt;
        uint256 updatedAt;
    }

    /// @notice Minimum ETH stake required to submit a campaign.
    uint256 public immutable minimumStake;

    /// @notice Treasury address that receives slashed stakes.
    address public immutable treasury;

    /// @notice Strategy registry reference for status checks.
    StrategyRegistry public immutable strategyRegistry;

    /// @dev Incremental campaign id cursor.
    uint64 private _campaignIdCursor;

    /// @dev Campaign storage.
    mapping(uint64 => Campaign) private _campaigns;

    /// @dev Enumerable list of campaign ids for discovery.
    EnumerableSet.UintSet private _campaignIds;

    /// @dev Mapping of campaign id to attached strategy ids.
    mapping(uint64 => EnumerableSet.UintSet) private _campaignStrategies;

    /// @notice Cached role ids.
    bytes32 public immutable CAMPAIGN_ADMIN_ROLE;
    bytes32 public immutable STRATEGY_ADMIN_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;

    /// @notice Campaign life-cycle events.
    event CampaignSubmitted(
        uint64 indexed id,
        address indexed creator,
        address indexed curator,
        address payout,
        string metadataURI,
        RegistryTypes.LockProfile defaultLock,
        uint256 stake
    );
    event CampaignApproved(uint64 indexed id, address indexed approver);
    event CampaignRejected(uint64 indexed id, address indexed approver, bool stakeSlashed);
    event CampaignStatusChanged(
        uint64 indexed id,
        RegistryTypes.CampaignStatus previousStatus,
        RegistryTypes.CampaignStatus newStatus,
        address indexed caller
    );
    event CuratorUpdated(uint64 indexed id, address indexed oldCurator, address indexed newCurator, address caller);
    event PayoutUpdated(uint64 indexed id, address indexed oldPayout, address indexed newPayout, address caller);
    event StrategyAttached(uint64 indexed id, uint64 indexed strategyId, address indexed caller);
    event StrategyDetached(uint64 indexed id, uint64 indexed strategyId, address indexed caller);
    event StakeRefunded(uint64 indexed id, address indexed recipient, uint256 amount);
    event StakeSlashed(uint64 indexed id, address indexed treasury, uint256 amount);

    constructor(address roleManager_, address treasury_, address strategyRegistry_, uint256 minimumStakeWei)
        RoleAware(roleManager_)
    {
        if (treasury_ == address(0) || strategyRegistry_ == address(0)) revert Errors.ZeroAddress();

        treasury = treasury_;
        strategyRegistry = StrategyRegistry(strategyRegistry_);
        minimumStake = minimumStakeWei;

        CAMPAIGN_ADMIN_ROLE = roleManager.ROLE_CAMPAIGN_ADMIN();
        STRATEGY_ADMIN_ROLE = roleManager.ROLE_STRATEGY_ADMIN();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
    }

    /*//////////////////////////////////////////////////////////////
                               CAMPAIGN REGISTRATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Permissionless campaign submission that escrows an ETH stake until approval.
    function submitCampaign(
        string calldata metadataURI,
        address curator,
        address payout,
        RegistryTypes.LockProfile defaultLock
    ) external payable whenNotPaused returns (uint64 id) {
        if (bytes(metadataURI).length == 0) revert Errors.InvalidMetadataCid();
        if (payout == address(0)) revert Errors.ZeroAddress();

        uint256 stakeAmount = msg.value;
        if (minimumStake > 0 && stakeAmount < minimumStake) {
            revert Errors.StakeTooLow(stakeAmount, minimumStake);
        }

        id = ++_campaignIdCursor;
        uint256 timestamp = block.timestamp;

        Campaign memory campaign = Campaign({
            id: id,
            creator: msg.sender,
            curator: curator == address(0) ? msg.sender : curator,
            payout: payout,
            defaultLock: defaultLock,
            status: RegistryTypes.CampaignStatus.Submitted,
            metadataURI: metadataURI,
            stake: uint96(stakeAmount),
            stakeRefunded: stakeAmount == 0,
            createdAt: timestamp,
            updatedAt: timestamp
        });

        _campaigns[id] = campaign;
        _campaignIds.add(id);

        emit CampaignSubmitted(id, campaign.creator, campaign.curator, payout, metadataURI, defaultLock, stakeAmount);
    }

    /// @notice Approves a submitted campaign, activates it, and refunds the escrowed stake to the creator.
    function approveCampaign(uint64 id) external onlyRole(CAMPAIGN_ADMIN_ROLE) whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (campaign.status != RegistryTypes.CampaignStatus.Submitted) revert Errors.StatusTransitionInvalid();

        campaign.status = RegistryTypes.CampaignStatus.Active;
        campaign.updatedAt = block.timestamp;

        _maybeRefundStake(campaign);

        emit CampaignApproved(id, msg.sender);
        emit CampaignStatusChanged(
            id, RegistryTypes.CampaignStatus.Submitted, RegistryTypes.CampaignStatus.Active, msg.sender
        );
    }

    /// @notice Rejects a campaign submission and optionally forwards the stake to treasury.
    function rejectCampaign(uint64 id, bool slashStake) external onlyRole(CAMPAIGN_ADMIN_ROLE) whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (campaign.status != RegistryTypes.CampaignStatus.Submitted) revert Errors.StatusTransitionInvalid();

        campaign.status = RegistryTypes.CampaignStatus.Cancelled;
        campaign.updatedAt = block.timestamp;

        if (campaign.stake > 0 && !campaign.stakeRefunded) {
            if (slashStake) {
                campaign.stakeRefunded = true;
                payable(treasury).sendValue(uint256(campaign.stake));
                emit StakeSlashed(id, treasury, uint256(campaign.stake));
            } else {
                _maybeRefundStake(campaign);
            }
        }

        emit CampaignRejected(id, msg.sender, slashStake);
        emit CampaignStatusChanged(
            id, RegistryTypes.CampaignStatus.Submitted, RegistryTypes.CampaignStatus.Cancelled, msg.sender
        );
    }

    /// @notice Allows campaign admins or curators to pause a live campaign.
    function pauseCampaign(uint64 id) external whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (
            msg.sender != campaign.curator && !roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)
                && !roleManager.hasRole(GUARDIAN_ROLE, msg.sender)
        ) {
            revert Errors.UnauthorizedCurator();
        }
        RegistryTypes.CampaignStatus previous = campaign.status;
        campaign.status = RegistryTypes.CampaignStatus.Paused;
        campaign.updatedAt = block.timestamp;

        emit CampaignStatusChanged(id, previous, RegistryTypes.CampaignStatus.Paused, msg.sender);
    }

    /// @notice Restores a paused campaign back to active state (admin or guardian).
    function resumeCampaign(uint64 id) external whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (!roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender) && !roleManager.hasRole(GUARDIAN_ROLE, msg.sender)) {
            revert Errors.UnauthorizedManager();
        }
        RegistryTypes.CampaignStatus previous = campaign.status;
        if (previous != RegistryTypes.CampaignStatus.Paused) revert Errors.StatusTransitionInvalid();

        campaign.status = RegistryTypes.CampaignStatus.Active;
        campaign.updatedAt = block.timestamp;

        emit CampaignStatusChanged(id, previous, RegistryTypes.CampaignStatus.Active, msg.sender);
    }

    /// @notice Marks a campaign as completed (e.g., goal reached) or archived.
    function setFinalStatus(uint64 id, RegistryTypes.CampaignStatus finalStatus) external {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (!roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)) revert Errors.UnauthorizedManager();
        if (
            finalStatus != RegistryTypes.CampaignStatus.Completed
                && finalStatus != RegistryTypes.CampaignStatus.Archived
                && finalStatus != RegistryTypes.CampaignStatus.Cancelled
        ) {
            revert Errors.StatusTransitionInvalid();
        }

        RegistryTypes.CampaignStatus previous = campaign.status;
        campaign.status = finalStatus;
        campaign.updatedAt = block.timestamp;

        emit CampaignStatusChanged(id, previous, finalStatus, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                               ADMIN UPDATES
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the curator responsible for a campaign.
    function updateCurator(uint64 id, address newCurator) external whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (newCurator == address(0)) revert Errors.ZeroAddress();
        if (msg.sender != campaign.curator && !roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)) {
            revert Errors.UnauthorizedCurator();
        }

        address oldCurator = campaign.curator;
        campaign.curator = newCurator;
        campaign.updatedAt = block.timestamp;

        emit CuratorUpdated(id, oldCurator, newCurator, msg.sender);
    }

    /// @notice Updates the payout address controlled by curator or admin.
    function updatePayout(uint64 id, address newPayout) external whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (newPayout == address(0)) revert Errors.ZeroAddress();
        if (msg.sender != campaign.curator && !roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)) {
            revert Errors.UnauthorizedCurator();
        }

        address oldPayout = campaign.payout;
        campaign.payout = newPayout;
        campaign.updatedAt = block.timestamp;

        emit PayoutUpdated(id, oldPayout, newPayout, msg.sender);
    }

    /// @notice Updates the default lock profile applied to new vaults.
    function updateDefaultLock(uint64 id, RegistryTypes.LockProfile newLock) external {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (msg.sender != campaign.curator && !roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, msg.sender)) {
            revert Errors.UnauthorizedCurator();
        }

        campaign.defaultLock = newLock;
        campaign.updatedAt = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                           STRATEGY ATTACHMENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Attaches an approved strategy to a campaign so vaults can be deployed for it.
    function attachStrategy(uint64 id, uint64 strategyId) external whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (!_isCuratorOrAdmin(campaign.curator, msg.sender)) revert Errors.UnauthorizedCurator();
        if (
            campaign.status != RegistryTypes.CampaignStatus.Active
                && campaign.status != RegistryTypes.CampaignStatus.Submitted
        ) {
            revert Errors.CampaignNotActive();
        }

        StrategyRegistry.Strategy memory strategy = strategyRegistry.getStrategy(strategyId);
        if (strategy.status != RegistryTypes.StrategyStatus.Active) revert Errors.StrategyInactive();

        EnumerableSet.UintSet storage strategies = _campaignStrategies[id];
        if (!strategies.add(strategyId)) revert Errors.StrategyAlreadyExists();

        emit StrategyAttached(id, strategyId, msg.sender);
    }

    /// @notice Removes a strategy association from a campaign.
    function detachStrategy(uint64 id, uint64 strategyId) external whenNotPaused {
        Campaign storage campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        if (!_isCuratorOrAdmin(campaign.curator, msg.sender)) revert Errors.UnauthorizedCurator();

        EnumerableSet.UintSet storage strategies = _campaignStrategies[id];
        if (!strategies.remove(strategyId)) revert Errors.StrategyNotFound();

        emit StrategyDetached(id, strategyId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns campaign metadata by id.
    function getCampaign(uint64 id) external view returns (Campaign memory) {
        Campaign memory campaign = _campaigns[id];
        if (campaign.id == 0) revert Errors.CampaignNotFound();
        return campaign;
    }

    /// @notice Returns the list of strategy ids attached to a campaign.
    function getCampaignStrategies(uint64 id) external view returns (uint64[] memory strategyIds) {
        EnumerableSet.UintSet storage setRef = _campaignStrategies[id];
        uint256 length = setRef.length();
        strategyIds = new uint64[](length);
        for (uint256 i = 0; i < length; ++i) {
            strategyIds[i] = uint64(setRef.at(i));
        }
    }

    /// @notice Checks whether a given strategy id is attached to a campaign.
    function isStrategyAttached(uint64 id, uint64 strategyId) external view returns (bool) {
        return _campaignStrategies[id].contains(strategyId);
    }

    /// @notice Returns total number of campaigns submitted.
    function campaignCount() external view returns (uint256) {
        return _campaignIds.length();
    }

    /// @notice Paginates through campaign ids for indexing.
    function listCampaignIds(uint256 offset, uint256 limit) external view returns (uint64[] memory ids) {
        uint256 total = _campaignIds.length();
        if (offset >= total) return new uint64[](0);

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 resultLength = end - offset;
        ids = new uint64[](resultLength);
        for (uint256 i = 0; i < resultLength; ++i) {
            ids[i] = uint64(_campaignIds.at(offset + i));
        }
    }

    /*//////////////////////////////////////////////////////////////
                                PAUSING
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNALS
    //////////////////////////////////////////////////////////////*/

    function _maybeRefundStake(Campaign storage campaign) private {
        if (campaign.stake == 0 || campaign.stakeRefunded) return;
        campaign.stakeRefunded = true;
        payable(campaign.creator).sendValue(uint256(campaign.stake));
        emit StakeRefunded(campaign.id, campaign.creator, uint256(campaign.stake));
    }

    function _isCuratorOrAdmin(address curator, address account) private view returns (bool) {
        if (account == curator) return true;
        if (roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, account)) return true;
        if (roleManager.hasRole(STRATEGY_ADMIN_ROLE, account)) return true;
        return false;
    }
}
