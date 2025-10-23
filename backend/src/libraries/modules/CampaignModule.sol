// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GiveProtocolStorage} from "../../core/GiveProtocolStorage.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ModuleBase} from "../utils/ModuleBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title CampaignModule
 * @author GIVE Protocol
 * @notice External library for campaign lifecycle management
 * @dev Following YOLO Protocol V1 pattern with external libraries for gas efficiency
 *      Handles campaign submission, approval, funding, staking, and status management
 */
library CampaignModule {
    using SafeERC20 for IERC20;
    using ModuleBase for GiveProtocolStorage.AppStorage;

    // ============================================================
    // EVENTS
    // ============================================================

    event CampaignSubmitted(
        bytes32 indexed campaignId,
        address indexed beneficiary,
        string name,
        string metadataURI,
        uint256 stakeAmount
    );

    event CampaignApproved(
        bytes32 indexed campaignId,
        address indexed curator,
        uint40 approvedAt
    );

    event CampaignRejected(
        bytes32 indexed campaignId,
        address indexed curator,
        string reason
    );

    event CampaignStatusChanged(
        bytes32 indexed campaignId,
        DataTypes.CampaignStatus oldStatus,
        DataTypes.CampaignStatus newStatus
    );

    event CampaignFunded(
        bytes32 indexed campaignId,
        uint256 amount,
        uint256 totalReceived
    );

    event CampaignWithdrawal(
        bytes32 indexed campaignId,
        address indexed recipient,
        uint256 amount
    );

    event CampaignStaked(
        bytes32 indexed campaignId,
        address indexed staker,
        uint256 amount,
        uint256 totalStake
    );

    event CampaignUnstaked(
        bytes32 indexed campaignId,
        address indexed staker,
        uint256 amount
    );

    event StakeSlashed(
        bytes32 indexed campaignId,
        address indexed recipient,
        uint256 amount
    );

    event CampaignCompleted(
        bytes32 indexed campaignId,
        uint256 totalReceived,
        uint40 completedAt
    );

    // ============================================================
    // ERRORS
    // ============================================================

    error CampaignModule__CampaignExists(bytes32 campaignId);
    error CampaignModule__CampaignNotFound(bytes32 campaignId);
    error CampaignModule__InvalidStatus(DataTypes.CampaignStatus status);
    error CampaignModule__InsufficientStake(uint256 provided, uint256 required);
    error CampaignModule__BeneficiaryHasCampaign(address beneficiary);
    error CampaignModule__NotPending(bytes32 campaignId);
    error CampaignModule__NotApproved(bytes32 campaignId);
    error CampaignModule__CampaignPaused(bytes32 campaignId);
    error CampaignModule__InsufficientFunds(uint256 available, uint256 requested);
    error CampaignModule__InsufficientStakeBalance(uint256 available, uint256 requested);

    // ============================================================
    // CAMPAIGN SUBMISSION
    // ============================================================

    /**
     * @notice Submit new campaign for approval
     * @param s Storage reference
     * @param beneficiary Campaign beneficiary address
     * @param name Campaign name
     * @param description Campaign description
     * @param metadataURI IPFS metadata URI
     * @param targetAmount Optional funding target (0 for no target)
     * @param stakeAmount Amount to stake for submission
     * @return campaignId Unique campaign identifier
     */
    function submitCampaign(
        GiveProtocolStorage.AppStorage storage s,
        address beneficiary,
        string memory name,
        string memory description,
        string memory metadataURI,
        uint256 targetAmount,
        uint256 stakeAmount
    ) external returns (bytes32 campaignId) {
        s.requireCampaignCreationNotPaused();
        ModuleBase.requireNonZeroAddress(beneficiary);
        
        // Check beneficiary doesn't already have a campaign
        if (s.beneficiaryCampaign[beneficiary] != bytes32(0)) {
            revert CampaignModule__BeneficiaryHasCampaign(beneficiary);
        }
        
        // Generate campaign ID
        campaignId = keccak256(abi.encodePacked(beneficiary, block.timestamp, s.campaignList.length));
        
        // Check campaign doesn't exist
        if (s.isCampaign[campaignId]) {
            revert CampaignModule__CampaignExists(campaignId);
        }
        
        // Validate minimum stake (if configured)
        uint256 minStake = 0; // Could be from s.riskParams or separate config
        if (stakeAmount < minStake) {
            revert CampaignModule__InsufficientStake(stakeAmount, minStake);
        }
        
        // Create campaign configuration
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        config.campaignId = campaignId;
        config.beneficiary = beneficiary;
        config.curator = address(0); // Not yet approved
        config.name = name;
        config.description = description;
        config.metadataURI = metadataURI;
        config.status = DataTypes.CampaignStatus.PENDING;
        config.totalReceived = 0;
        config.targetAmount = targetAmount;
        config.minStakeAmount = minStake;
        config.stakeAmount = stakeAmount;
        config.createdAt = uint40(block.timestamp);
        config.approvedAt = 0;
        config.completedAt = 0;
        
        // Register campaign
        s.campaignList.push(campaignId);
        s.isCampaign[campaignId] = true;
        s.beneficiaryCampaign[beneficiary] = campaignId;
        
        // Track stake if provided
        if (stakeAmount > 0) {
            s.campaignStakes[campaignId] = stakeAmount;
            s.userCampaignStakes[msg.sender][campaignId] = stakeAmount;
        }
        
        // Update metrics
        s.metrics.totalCampaigns++;
        
        emit CampaignSubmitted(campaignId, beneficiary, name, metadataURI, stakeAmount);
        
        return campaignId;
    }

    // ============================================================
    // CAMPAIGN CURATION
    // ============================================================

    /**
     * @notice Approve pending campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param curator Curator approving the campaign
     */
    function approveCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        address curator
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        ModuleBase.requireNonZeroAddress(curator);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Check status is PENDING
        if (config.status != DataTypes.CampaignStatus.PENDING) {
            revert CampaignModule__NotPending(campaignId);
        }
        
        // Update campaign
        DataTypes.CampaignStatus oldStatus = config.status;
        config.status = DataTypes.CampaignStatus.APPROVED;
        config.curator = curator;
        config.approvedAt = uint40(block.timestamp);
        
        // Update metrics
        s.metrics.activeCampaigns++;
        
        emit CampaignApproved(campaignId, curator, uint40(block.timestamp));
        emit CampaignStatusChanged(campaignId, oldStatus, DataTypes.CampaignStatus.APPROVED);
    }

    /**
     * @notice Reject pending campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param curator Curator rejecting the campaign
     * @param reason Rejection reason
     */
    function rejectCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        address curator,
        string memory reason
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        ModuleBase.requireNonZeroAddress(curator);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Check status is PENDING
        if (config.status != DataTypes.CampaignStatus.PENDING) {
            revert CampaignModule__NotPending(campaignId);
        }
        
        // Update campaign
        DataTypes.CampaignStatus oldStatus = config.status;
        config.status = DataTypes.CampaignStatus.REJECTED;
        config.curator = curator;
        
        emit CampaignRejected(campaignId, curator, reason);
        emit CampaignStatusChanged(campaignId, oldStatus, DataTypes.CampaignStatus.REJECTED);
        
        // Slash stake to treasury if any
        uint256 stake = s.campaignStakes[campaignId];
        if (stake > 0) {
            _slashStake(s, campaignId, s.protocolTreasury);
        }
    }

    /**
     * @notice Pause approved campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     */
    function pauseCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Can only pause APPROVED campaigns
        if (config.status != DataTypes.CampaignStatus.APPROVED) {
            revert CampaignModule__NotApproved(campaignId);
        }
        
        DataTypes.CampaignStatus oldStatus = config.status;
        config.status = DataTypes.CampaignStatus.PAUSED;
        s.campaignPaused[campaignId] = true;
        
        // Update metrics
        if (s.metrics.activeCampaigns > 0) {
            s.metrics.activeCampaigns--;
        }
        
        emit CampaignStatusChanged(campaignId, oldStatus, DataTypes.CampaignStatus.PAUSED);
    }

    /**
     * @notice Resume paused campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     */
    function resumeCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Can only resume PAUSED campaigns
        if (config.status != DataTypes.CampaignStatus.PAUSED) {
            revert CampaignModule__InvalidStatus(config.status);
        }
        
        DataTypes.CampaignStatus oldStatus = config.status;
        config.status = DataTypes.CampaignStatus.APPROVED;
        s.campaignPaused[campaignId] = false;
        
        // Update metrics
        s.metrics.activeCampaigns++;
        
        emit CampaignStatusChanged(campaignId, oldStatus, DataTypes.CampaignStatus.APPROVED);
    }

    /**
     * @notice Complete campaign (manual or when target reached)
     * @param s Storage reference
     * @param campaignId Campaign identifier
     */
    function completeCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) public {
        ModuleBase.requireCampaignExists(s, campaignId);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Can only complete APPROVED or PAUSED campaigns
        if (config.status != DataTypes.CampaignStatus.APPROVED && config.status != DataTypes.CampaignStatus.PAUSED) {
            revert CampaignModule__InvalidStatus(config.status);
        }
        
        DataTypes.CampaignStatus oldStatus = config.status;
        config.status = DataTypes.CampaignStatus.COMPLETED;
        config.completedAt = uint40(block.timestamp);
        
        // Update metrics
        if (s.metrics.activeCampaigns > 0) {
            s.metrics.activeCampaigns--;
        }
        
        emit CampaignCompleted(campaignId, config.totalReceived, uint40(block.timestamp));
        emit CampaignStatusChanged(campaignId, oldStatus, DataTypes.CampaignStatus.COMPLETED);
        
        // Return stake to submitter if any
        _returnStake(s, campaignId);
    }

    /**
     * @notice Fade out inactive campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     */
    function fadeCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        DataTypes.CampaignStatus oldStatus = config.status;
        config.status = DataTypes.CampaignStatus.FADED;
        
        // Update metrics if was active
        if (oldStatus == DataTypes.CampaignStatus.APPROVED && s.metrics.activeCampaigns > 0) {
            s.metrics.activeCampaigns--;
        }
        
        emit CampaignStatusChanged(campaignId, oldStatus, DataTypes.CampaignStatus.FADED);
    }

    // ============================================================
    // CAMPAIGN FUNDING
    // ============================================================

    /**
     * @notice Record funding received by campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param amount Amount received
     */
    function recordFunding(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        uint256 amount
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        ModuleBase.requireNonZeroAmount(amount);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Check campaign is approved and not paused
        if (config.status != DataTypes.CampaignStatus.APPROVED) {
            revert CampaignModule__NotApproved(campaignId);
        }
        if (s.campaignPaused[campaignId]) {
            revert CampaignModule__CampaignPaused(campaignId);
        }
        
        // Update funding
        config.totalReceived += amount;
        
        emit CampaignFunded(campaignId, amount, config.totalReceived);
        
        // Auto-complete if target reached
        if (config.targetAmount > 0 && config.totalReceived >= config.targetAmount) {
            completeCampaign(s, campaignId);
        }
    }

    /**
     * @notice Withdraw campaign funds to beneficiary
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param amount Amount to withdraw
     * @param recipient Recipient address (usually beneficiary)
     */
    function withdrawCampaignFunds(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        uint256 amount,
        address recipient
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        ModuleBase.requireNonZeroAmount(amount);
        ModuleBase.requireNonZeroAddress(recipient);
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        
        // Verify sufficient funds
        if (config.totalReceived < amount) {
            revert CampaignModule__InsufficientFunds(config.totalReceived, amount);
        }
        
        // Update total received
        config.totalReceived -= amount;
        
        emit CampaignWithdrawal(campaignId, recipient, amount);
        
        // Note: Actual token transfer would happen in calling contract
        // IERC20(asset).safeTransfer(recipient, amount);
    }

    // ============================================================
    // CAMPAIGN STAKING
    // ============================================================

    /**
     * @notice Stake tokens for a campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param staker Staker address
     * @param amount Amount to stake
     */
    function stakeCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        address staker,
        uint256 amount
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        ModuleBase.requireNonZeroAddress(staker);
        ModuleBase.requireNonZeroAmount(amount);
        
        // Update stakes
        s.campaignStakes[campaignId] += amount;
        s.userCampaignStakes[staker][campaignId] += amount;
        
        emit CampaignStaked(campaignId, staker, amount, s.campaignStakes[campaignId]);
        
        // Note: Actual token transfer would happen in calling contract
        // IERC20(stakeToken).safeTransferFrom(staker, address(this), amount);
    }

    /**
     * @notice Unstake tokens from a campaign
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param staker Staker address
     * @param amount Amount to unstake
     */
    function unstakeCampaign(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        address staker,
        uint256 amount
    ) external {
        ModuleBase.requireCampaignExists(s, campaignId);
        ModuleBase.requireNonZeroAddress(staker);
        ModuleBase.requireNonZeroAmount(amount);
        
        // Verify sufficient stake balance
        uint256 stakerBalance = s.userCampaignStakes[staker][campaignId];
        if (stakerBalance < amount) {
            revert CampaignModule__InsufficientStakeBalance(stakerBalance, amount);
        }
        
        // Update stakes
        s.campaignStakes[campaignId] -= amount;
        s.userCampaignStakes[staker][campaignId] -= amount;
        
        emit CampaignUnstaked(campaignId, staker, amount);
        
        // Note: Actual token transfer would happen in calling contract
        // IERC20(stakeToken).safeTransfer(staker, amount);
    }

    // ============================================================
    // QUERY FUNCTIONS
    // ============================================================

    /**
     * @notice Get campaign configuration
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @return config Campaign configuration
     */
    function getCampaignConfig(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) external view returns (DataTypes.CampaignConfig memory) {
        ModuleBase.requireCampaignExists(s, campaignId);
        return s.campaigns[campaignId];
    }

    /**
     * @notice Get campaign by beneficiary
     * @param s Storage reference
     * @param beneficiary Beneficiary address
     * @return campaignId Campaign identifier
     */
    function getCampaignByBeneficiary(
        GiveProtocolStorage.AppStorage storage s,
        address beneficiary
    ) external view returns (bytes32) {
        return s.beneficiaryCampaign[beneficiary];
    }

    /**
     * @notice Get all campaigns
     * @param s Storage reference
     * @return campaigns Array of campaign IDs
     */
    function getAllCampaigns(
        GiveProtocolStorage.AppStorage storage s
    ) external view returns (bytes32[] memory) {
        return s.campaignList;
    }

    /**
     * @notice Get approved campaigns
     * @param s Storage reference
     * @return campaigns Array of approved campaign IDs
     */
    function getApprovedCampaigns(
        GiveProtocolStorage.AppStorage storage s
    ) external view returns (bytes32[] memory) {
        return _getCampaignsByStatus(s, DataTypes.CampaignStatus.APPROVED);
    }

    /**
     * @notice Get pending campaigns
     * @param s Storage reference
     * @return campaigns Array of pending campaign IDs
     */
    function getPendingCampaigns(
        GiveProtocolStorage.AppStorage storage s
    ) external view returns (bytes32[] memory) {
        return _getCampaignsByStatus(s, DataTypes.CampaignStatus.PENDING);
    }

    /**
     * @notice Get campaign stake amount
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @return stake Total stake amount
     */
    function getCampaignStake(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) external view returns (uint256) {
        return s.campaignStakes[campaignId];
    }

    /**
     * @notice Get user's stake in campaign
     * @param s Storage reference
     * @param staker Staker address
     * @param campaignId Campaign identifier
     * @return stake User's stake amount
     */
    function getUserCampaignStake(
        GiveProtocolStorage.AppStorage storage s,
        address staker,
        bytes32 campaignId
    ) external view returns (uint256) {
        return s.userCampaignStakes[staker][campaignId];
    }

    /**
     * @notice Check if campaign is operational (approved and not paused)
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @return isOperational True if campaign is operational
     */
    function isCampaignOperational(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) external view returns (bool) {
        if (!s.isCampaign[campaignId]) return false;
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        return config.status == DataTypes.CampaignStatus.APPROVED && !s.campaignPaused[campaignId];
    }

    // ============================================================
    // INTERNAL HELPERS
    // ============================================================

    /**
     * @notice Get campaigns by status
     * @param s Storage reference
     * @param status Campaign status to filter by
     * @return campaigns Array of campaign IDs with given status
     */
    function _getCampaignsByStatus(
        GiveProtocolStorage.AppStorage storage s,
        DataTypes.CampaignStatus status
    ) private view returns (bytes32[] memory) {
        uint256 count = 0;
        uint256 length = s.campaignList.length;
        
        // Count campaigns with status
        for (uint256 i = 0; i < length; i++) {
            if (s.campaigns[s.campaignList[i]].status == status) {
                count++;
            }
        }
        
        // Populate array
        bytes32[] memory campaigns = new bytes32[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < length; i++) {
            bytes32 campaignId = s.campaignList[i];
            if (s.campaigns[campaignId].status == status) {
                campaigns[index] = campaignId;
                index++;
            }
        }
        
        return campaigns;
    }

    /**
     * @notice Slash campaign stake to recipient
     * @param s Storage reference
     * @param campaignId Campaign identifier
     * @param recipient Recipient of slashed stake
     */
    function _slashStake(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId,
        address recipient
    ) private {
        uint256 stake = s.campaignStakes[campaignId];
        if (stake == 0) return;
        
        s.campaignStakes[campaignId] = 0;
        
        emit StakeSlashed(campaignId, recipient, stake);
        
        // Note: Actual token transfer would happen in calling contract
        // IERC20(stakeToken).safeTransfer(recipient, stake);
    }

    /**
     * @notice Return campaign stake to submitter
     * @param s Storage reference
     * @param campaignId Campaign identifier
     */
    function _returnStake(
        GiveProtocolStorage.AppStorage storage s,
        bytes32 campaignId
    ) private {
        uint256 stake = s.campaignStakes[campaignId];
        if (stake == 0) return;
        
        DataTypes.CampaignConfig storage config = s.campaigns[campaignId];
        address beneficiary = config.beneficiary;
        
        s.campaignStakes[campaignId] = 0;
        
        // Note: Actual token transfer would happen in calling contract
        // IERC20(stakeToken).safeTransfer(beneficiary, stake);
    }
}
