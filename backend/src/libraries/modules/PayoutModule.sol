// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GiveProtocolStorage} from "../../core/GiveProtocolStorage.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {ModuleBase} from "../utils/ModuleBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PayoutModule
 * @author GIVE Protocol
 * @notice External library for yield distribution and payout management
 * @dev Following YOLO Protocol V1 pattern with external libraries for gas efficiency
 *      Replaces DonationRouter with modular architecture
 *      Implements staking-style accounting for yield distribution
 */
library PayoutModule {
    using SafeERC20 for IERC20;
    using ModuleBase for GiveProtocolStorage.AppStorage;

    // ============================================================
    // EVENTS
    // ============================================================

    event UserPreferenceUpdated(
        address indexed user,
        address indexed vault,
        address indexed campaign,
        uint256 allocationBps,
        address personalBeneficiary
    );

    event YieldDistributed(
        uint256 indexed distributionId,
        address indexed vault,
        address indexed asset,
        uint256 totalYield,
        uint256 campaignYield,
        uint256 personalYield,
        uint256 protocolFee
    );

    event YieldClaimed(
        address indexed user,
        address indexed vault,
        address indexed asset,
        uint256 amount
    );

    event UserSharesUpdated(
        address indexed user,
        address indexed vault,
        uint256 oldShares,
        uint256 newShares
    );

    event RewardDebtRefreshed(
        address indexed user,
        address indexed vault,
        uint256 rewardDebt
    );

    // ============================================================
    // ERRORS
    // ============================================================

    error PayoutModule__InvalidAllocation(uint256 allocation);
    error PayoutModule__CampaignNotOperational(bytes32 campaignId);
    error PayoutModule__NoYieldToDistribute();
    error PayoutModule__NoYieldToClaim();
    error PayoutModule__SharesMismatch(uint256 expected, uint256 actual);
    error PayoutModule__InvalidBeneficiary(address beneficiary);

    // ============================================================
    // USER PREFERENCES
    // ============================================================

    /**
     * @notice Set user's yield allocation preference
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @param campaign Campaign to receive yield
     * @param allocationBps Allocation percentage (5000=50%, 7500=75%, 10000=100%)
     * @param personalBeneficiary Address for personal yield (if < 100% to campaign)
     */
    function setUserPreference(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault,
        address campaign,
        uint256 allocationBps,
        address personalBeneficiary
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireNonZeroAddress(user);
        
        // Validate allocation (must be 50%, 75%, or 100%)
        bool validAllocation = 
            allocationBps == DataTypes.ALLOCATION_50_BPS ||
            allocationBps == DataTypes.ALLOCATION_75_BPS ||
            allocationBps == DataTypes.ALLOCATION_100_BPS;
        
        if (!validAllocation) {
            revert PayoutModule__InvalidAllocation(allocationBps);
        }
        
        // Validate campaign if specified
        bytes32 campaignId = bytes32(0);
        if (campaign != address(0)) {
            campaignId = s.beneficiaryCampaign[campaign];
            if (campaignId == bytes32(0)) {
                revert PayoutModule__CampaignNotOperational(campaignId);
            }
            
            // Check campaign is operational
            DataTypes.CampaignConfig storage campaignConfig = s.campaigns[campaignId];
            if (campaignConfig.status != DataTypes.CampaignStatus.APPROVED || s.campaignPaused[campaignId]) {
                revert PayoutModule__CampaignNotOperational(campaignId);
            }
        }
        
        // Validate personal beneficiary if allocation < 100%
        if (allocationBps < DataTypes.ALLOCATION_100_BPS) {
            if (personalBeneficiary == address(0)) {
                revert PayoutModule__InvalidBeneficiary(personalBeneficiary);
            }
        }
        
        // Settle user before updating preference
        _settleUser(s, user, vault);
        
        // Update preference
        DataTypes.UserPreference storage pref = s.preferences[user][vault];
        pref.user = user;
        pref.vault = vault;
        pref.selectedCampaign = campaign;
        pref.allocationBps = allocationBps;
        pref.personalBeneficiary = personalBeneficiary;
        pref.lastUpdated = uint40(block.timestamp);
        
        // Refresh reward debt after preference change
        _refreshRewardDebt(s, user, vault);
        
        emit UserPreferenceUpdated(user, vault, campaign, allocationBps, personalBeneficiary);
    }

    /**
     * @notice Get user's preference
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @return preference User preference struct
     */
    function getUserPreference(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) external view returns (DataTypes.UserPreference memory) {
        return s.preferences[user][vault];
    }

    // ============================================================
    // YIELD DISTRIBUTION
    // ============================================================

    /**
     * @notice Distribute yield to all users based on preferences
     * @param s Storage reference
     * @param vault Vault distributing yield
     * @param asset Asset being distributed
     * @param totalYield Total yield to distribute
     * @return distributionId Distribution record ID
     */
    function distributeYield(
        GiveProtocolStorage.AppStorage storage s,
        address vault,
        address asset,
        uint256 totalYield
    ) external returns (uint256 distributionId) {
        s.requireHarvestNotPaused();
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireNonZeroAmount(totalYield);
        
        // Calculate protocol fee
        uint256 protocolFeeBps = s.feeConfig.protocolFeeBps;
        uint256 protocolFee = ModuleBase.calculateBps(totalYield, protocolFeeBps);
        uint256 distributable = totalYield - protocolFee;
        
        // Create distribution record
        distributionId = ++s.distributionCounter;
        DataTypes.DistributionRecord storage record = s.distributions[distributionId];
        record.distributionId = distributionId;
        record.vault = vault;
        record.asset = asset;
        record.totalYield = totalYield;
        record.protocolFee = protocolFee;
        record.timestamp = uint40(block.timestamp);
        
        // Track vault distributions
        s.vaultDistributions[vault].push(distributionId);
        
        // Note: In production, this would iterate through vault positions
        // and calculate allocations based on shares and preferences
        // For now, we set placeholder values
        record.campaignYield = 0;
        record.personalYield = 0;
        record.userCount = 0;
        
        // Update protocol metrics
        s.metrics.totalYieldDistributed += totalYield;
        s.metrics.totalProtocolFees += protocolFee;
        
        emit YieldDistributed(
            distributionId,
            vault,
            asset,
            totalYield,
            record.campaignYield,
            record.personalYield,
            protocolFee
        );
        
        return distributionId;
    }

    /**
     * @notice Calculate pending yield for user
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @return pendingYield Pending yield amount
     */
    function calculatePendingYield(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) external view returns (uint256 pendingYield) {
        DataTypes.UserYield storage userYield = s.userYields[user][vault];
        return userYield.pendingYield;
    }

    /**
     * @notice Claim pending yield for user
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @return claimed Amount claimed
     */
    function claimYield(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) external returns (uint256 claimed) {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireNonZeroAddress(user);
        
        // Settle user to update pending yield
        _settleUser(s, user, vault);
        
        DataTypes.UserYield storage userYield = s.userYields[user][vault];
        claimed = userYield.pendingYield;
        
        if (claimed == 0) {
            revert PayoutModule__NoYieldToClaim();
        }
        
        // Update tracking
        userYield.pendingYield = 0;
        userYield.claimedYield += claimed;
        
        // Get asset and personal beneficiary
        DataTypes.VaultConfig storage vaultConfig = s.vaults[vault];
        address asset = vaultConfig.asset;
        
        DataTypes.UserPreference storage pref = s.preferences[user][vault];
        address recipient = pref.personalBeneficiary != address(0) 
            ? pref.personalBeneficiary 
            : user;
        
        emit YieldClaimed(user, vault, asset, claimed);
        
        // Note: Actual token transfer would happen in calling contract
        // IERC20(asset).safeTransfer(recipient, claimed);
        
        return claimed;
    }

    // ============================================================
    // SHARE ACCOUNTING (STAKING-STYLE)
    // ============================================================

    /**
     * @notice Update user's shares in vault (called on deposit/withdraw)
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @param newShares New share balance
     * @param oldShares Old share balance (for verification)
     */
    function updateUserShares(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault,
        uint256 newShares,
        uint256 oldShares
    ) external {
        ModuleBase.requireVaultExists(s, vault);
        ModuleBase.requireNonZeroAddress(user);
        
        // Settle user before updating shares
        _settleUser(s, user, vault);
        
        // Verify old shares match
        DataTypes.UserPosition storage position = s.positions[user][vault];
        if (position.shares != oldShares) {
            revert PayoutModule__SharesMismatch(oldShares, position.shares);
        }
        
        // Update position
        position.shares = newShares;
        
        // Refresh reward debt after share change
        _refreshRewardDebt(s, user, vault);
        
        emit UserSharesUpdated(user, vault, oldShares, newShares);
    }

    /**
     * @notice Settle user's pending yield
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     */
    function _settleUser(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) private {
        DataTypes.UserPosition storage position = s.positions[user][vault];
        DataTypes.UserYield storage userYield = s.userYields[user][vault];
        
        if (position.shares == 0) {
            return;
        }
        
        // Note: In production, this would calculate yield based on:
        // accumulatedYieldPerShare - rewardDebt
        // For now, this is a placeholder
        
        // userYield.pendingYield += calculatedYield;
    }

    /**
     * @notice Refresh user's reward debt after share or preference change
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     */
    function _refreshRewardDebt(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) private {
        DataTypes.UserPosition storage position = s.positions[user][vault];
        DataTypes.UserYield storage userYield = s.userYields[user][vault];
        
        if (position.shares == 0) {
            userYield.rewardDebt = 0;
            return;
        }
        
        // Note: In production, this would calculate:
        // rewardDebt = shares * accumulatedYieldPerShare
        // For now, this is a placeholder
        
        emit RewardDebtRefreshed(user, vault, userYield.rewardDebt);
    }

    // ============================================================
    // QUERY FUNCTIONS
    // ============================================================

    /**
     * @notice Get pending yield for user
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @return pendingYield Pending yield amount
     */
    function getPendingYield(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) external view returns (uint256) {
        return s.userYields[user][vault].pendingYield;
    }

    /**
     * @notice Get claimed yield for user
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @return claimedYield Total claimed yield
     */
    function getClaimedYield(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) external view returns (uint256) {
        return s.userYields[user][vault].claimedYield;
    }

    /**
     * @notice Get distribution record
     * @param s Storage reference
     * @param distributionId Distribution ID
     * @return record Distribution record
     */
    function getDistributionRecord(
        GiveProtocolStorage.AppStorage storage s,
        uint256 distributionId
    ) external view returns (DataTypes.DistributionRecord memory) {
        return s.distributions[distributionId];
    }

    /**
     * @notice Get vault distributions
     * @param s Storage reference
     * @param vault Vault address
     * @return distributions Array of distribution IDs
     */
    function getVaultDistributions(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (uint256[] memory) {
        ModuleBase.requireVaultExists(s, vault);
        return s.vaultDistributions[vault];
    }

    /**
     * @notice Get user distributions (distributions where user received yield)
     * @param s Storage reference
     * @param user User address
     * @return distributions Array of distribution IDs
     */
    function getUserDistributions(
        GiveProtocolStorage.AppStorage storage s,
        address user
    ) external view returns (uint256[] memory) {
        // Note: This would require additional tracking in production
        // For now, return empty array
        return new uint256[](0);
    }

    /**
     * @notice Get total distributed yield for vault
     * @param s Storage reference
     * @param vault Vault address
     * @return totalDistributed Total yield distributed
     */
    function getTotalDistributed(
        GiveProtocolStorage.AppStorage storage s,
        address vault
    ) external view returns (uint256 totalDistributed) {
        uint256[] memory distributionIds = s.vaultDistributions[vault];
        
        for (uint256 i = 0; i < distributionIds.length; i++) {
            totalDistributed += s.distributions[distributionIds[i]].totalYield;
        }
        
        return totalDistributed;
    }

    /**
     * @notice Get user's yield data
     * @param s Storage reference
     * @param user User address
     * @param vault Vault address
     * @return yieldData User yield data
     */
    function getUserYieldData(
        GiveProtocolStorage.AppStorage storage s,
        address user,
        address vault
    ) external view returns (DataTypes.UserYield memory) {
        return s.userYields[user][vault];
    }
}
