// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {RoleAware} from "../access/RoleAware.sol";
import {Errors} from "../utils/Errors.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {CampaignRegistry} from "../campaign/CampaignRegistry.sol";

/// @title PayoutRouter
/// @notice Handles epoch-based yield distribution for campaign vaults with protocol fee capture.
contract PayoutRouter is RoleAware, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant PROTOCOL_FEE_BPS = 2_000; // 20%

    struct VaultInfo {
        uint64 campaignId;
        uint64 strategyId;
        bool registered;
    }

    CampaignRegistry public immutable campaignRegistry;
    address public protocolTreasury;

    uint256 public epochDuration = 7 days;

    bytes32 public immutable TREASURY_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;
    bytes32 public immutable CAMPAIGN_ADMIN_ROLE;

    mapping(address => VaultInfo) public vaultInfo;
    mapping(address => uint256) public lastEpochProcessed;
    mapping(address => bool) public authorizedCallers;

    event VaultRegistered(address indexed vault, uint64 campaignId, uint64 strategyId);
    event CampaignPayout(
        address indexed vault,
        uint64 indexed campaignId,
        uint64 indexed strategyId,
        address asset,
        uint256 grossAmount,
        uint256 protocolFee,
        uint256 netAmount,
        uint256 epochTimestamp,
        address payoutAddress
    );
    event ProtocolTreasuryUpdated(address indexed newTreasury);
    event EpochDurationUpdated(uint256 oldDuration, uint256 newDuration);

    constructor(address roleManager_, address campaignRegistry_, address protocolTreasury_)
        RoleAware(roleManager_)
    {
        if (campaignRegistry_ == address(0) || protocolTreasury_ == address(0)) revert Errors.ZeroAddress();
        campaignRegistry = CampaignRegistry(campaignRegistry_);
        protocolTreasury = protocolTreasury_;

        TREASURY_ROLE = roleManager.ROLE_TREASURY();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
        CAMPAIGN_ADMIN_ROLE = roleManager.ROLE_CAMPAIGN_ADMIN();
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN ACTIONS
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    function setProtocolTreasury(address newTreasury) external onlyRole(TREASURY_ROLE) {
        if (newTreasury == address(0)) revert Errors.ZeroAddress();
        protocolTreasury = newTreasury;
        emit ProtocolTreasuryUpdated(newTreasury);
    }

    function setEpochDuration(uint256 newDuration) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        require(newDuration >= 1 days, "epoch-too-short");
        uint256 old = epochDuration;
        epochDuration = newDuration;
        emit EpochDurationUpdated(old, newDuration);
    }

    /// @notice Registers a vault so that future harvests can be processed.
    function registerVault(address vault, uint64 campaignId, uint64 strategyId) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        if (vault == address(0)) revert Errors.ZeroAddress();

        // Ensure campaign exists and strategy is attached
        campaignRegistry.getCampaign(campaignId);
        if (!campaignRegistry.isStrategyAttached(campaignId, strategyId)) revert Errors.StrategyNotFound();

        vaultInfo[vault] = VaultInfo({campaignId: campaignId, strategyId: strategyId, registered: true});
        authorizedCallers[vault] = true;

        emit VaultRegistered(vault, campaignId, strategyId);
    }

    /// @notice Compatibility helper retained for legacy calls (no-op beyond recording flag).
    function setAuthorizedCaller(address caller, bool authorized) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        authorizedCallers[caller] = authorized;
    }

    /// @notice Compatibility helper for vault share tracking (no-op).
    function updateUserShares(address, address, uint256) external {}

    /*//////////////////////////////////////////////////////////////
                                PAYOUT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Called by vaults when distributing harvested yield.
    function distributeToAllUsers(address asset, uint256 totalYield)
        external
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (totalYield == 0) return 0;

        VaultInfo memory info = vaultInfo[msg.sender];
        if (!info.registered || !authorizedCallers[msg.sender]) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }

        uint256 last = lastEpochProcessed[msg.sender];
        if (last != 0) {
            uint256 nextEpoch = last + epochDuration;
            if (block.timestamp < nextEpoch) revert Errors.EpochNotReady(nextEpoch);
        }
        lastEpochProcessed[msg.sender] = block.timestamp;

        CampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(info.campaignId);
        if (campaign.status != RegistryTypes.CampaignStatus.Active) revert Errors.CampaignNotActive();

        IERC20 token = IERC20(asset);
        uint256 protocolFee = (totalYield * PROTOCOL_FEE_BPS) / BASIS_POINTS;
        uint256 netAmount = totalYield - protocolFee;

        if (protocolFee > 0) {
            token.safeTransfer(protocolTreasury, protocolFee);
        }
        if (netAmount > 0) {
            token.safeTransfer(campaign.payout, netAmount);
        }

        emit CampaignPayout(
            msg.sender,
            info.campaignId,
            info.strategyId,
            asset,
            totalYield,
            protocolFee,
            netAmount,
            block.timestamp,
            campaign.payout
        );

        return totalYield;
    }
}
