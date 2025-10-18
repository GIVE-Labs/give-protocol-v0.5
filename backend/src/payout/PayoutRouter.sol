// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {RoleAware} from "../access/RoleAware.sol";
import {Errors} from "../utils/Errors.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {CampaignRegistry} from "../campaign/CampaignRegistry.sol";

/// @title PayoutRouter
/// @notice Handles epoch-based yield distribution for campaign vaults with protocol fee capture.
contract PayoutRouter is RoleAware, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_PROTOCOL_FEE_BPS = 2_500; // 25% max
    uint256 public constant ACC_PRECISION = 1e18;
    uint256 public protocolFeeBps = 1_000; // 10% default

    struct VaultInfo {
        uint64 campaignId;
        uint64 strategyId;
        address asset;
        bool registered;
    }

    /// @notice User yield allocation preference per vault
    struct UserYieldPreference {
        uint8 campaignAllocation; // 50, 75, or 100
        address beneficiary; // recipient for remaining yield
    }

    struct VaultAccounting {
        uint256 totalShares;
        uint256 totalShares50;
        uint256 totalShares75;
        uint256 accPersonalPerShare50;
        uint256 accPersonalPerShare75;
    }

    struct UserAccounting {
        uint256 shares;
        uint256 rewardDebt;
        uint256 pendingPersonal;
        uint8 allocation;
    }

    CampaignRegistry public immutable campaignRegistry;
    address public protocolTreasury;

    uint256 public epochDuration = 7 days;

    bytes32 public immutable TREASURY_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;
    bytes32 public immutable CAMPAIGN_ADMIN_ROLE;

    mapping(address => VaultInfo) public vaultInfo;
    mapping(address => VaultAccounting) internal vaultAccounting;
    mapping(address => mapping(address => UserAccounting)) internal userAccounting;
    mapping(address => bool) public authorizedCallers;
    mapping(address => bool) public authorizedSchedulers;
    mapping(address => mapping(address => UserYieldPreference)) public userVaultPreferences;
    mapping(address => mapping(address => uint256)) public userVaultShares;

    event UserSharesUpdated(address indexed vault, address indexed user, uint256 shares, uint256 totalShares);
    event YieldPreferenceUpdated(
        address indexed user, address indexed vault, uint8 campaignAllocation, address beneficiary
    );
    event VaultRegistered(address indexed vault, uint64 campaignId, uint64 strategyId, address asset);
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
    event SchedulerAuthorizationUpdated(address indexed scheduler, bool authorized);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event PersonalYieldClaimed(address indexed vault, address indexed user, address indexed beneficiary, uint256 amount);

    constructor(address roleManager_, address campaignRegistry_, address protocolTreasury_) RoleAware(roleManager_) {
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

    function setScheduler(address scheduler, bool authorized) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        authorizedSchedulers[scheduler] = authorized;
        emit SchedulerAuthorizationUpdated(scheduler, authorized);
    }

    function setProtocolFee(uint256 newFeeBps) external onlyRole(TREASURY_ROLE) {
        require(newFeeBps <= MAX_PROTOCOL_FEE_BPS, "Fee exceeds maximum");
        uint256 oldFee = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(oldFee, newFeeBps);
    }

    /// @notice Registers a vault so that future harvests can be processed.
    function registerVault(address vault, uint64 campaignId, uint64 strategyId)
        external
        onlyRole(CAMPAIGN_ADMIN_ROLE)
    {
        if (vault == address(0)) revert Errors.ZeroAddress();

        // Ensure campaign exists and strategy is attached
        campaignRegistry.getCampaign(campaignId);
        if (!campaignRegistry.isStrategyAttached(campaignId, strategyId)) revert Errors.StrategyNotFound();

        address asset = IERC4626(vault).asset();
        vaultInfo[vault] = VaultInfo({campaignId: campaignId, strategyId: strategyId, asset: asset, registered: true});
        authorizedCallers[vault] = true;

        emit VaultRegistered(vault, campaignId, strategyId, asset);
    }

    /// @notice Compatibility helper retained for legacy calls (no-op beyond recording flag).
    function setAuthorizedCaller(address caller, bool authorized) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        authorizedCallers[caller] = authorized;
    }

    /// @notice Vaults update supporter share balances for allocation calculations.
    function updateUserShares(address user, address vault, uint256 newShares) external {
        if (msg.sender != vault) revert Errors.UnauthorizedCaller(msg.sender);
        VaultInfo storage info = vaultInfo[vault];
        if (!info.registered) revert Errors.UnauthorizedCaller(vault);

        uint256 actual = IERC20(vault).balanceOf(user);
        require(actual == newShares, "shares mismatch");

        userVaultShares[user][vault] = newShares;

        VaultAccounting storage accounting = vaultAccounting[vault];
        UserAccounting storage userState = userAccounting[vault][user];

        _settleUser(vault, accounting, userState, user);

        // Remove previous share amounts from aggregates
        uint8 previousAllocation = userState.allocation;
        if (!_isValidAllocation(previousAllocation)) previousAllocation = 100;

        if (userState.shares > 0) {
            accounting.totalShares -= userState.shares;
            if (previousAllocation == 50) {
                accounting.totalShares50 -= userState.shares;
            } else if (previousAllocation == 75) {
                accounting.totalShares75 -= userState.shares;
            }
        }

        userState.shares = newShares;

        uint8 effectiveAllocation = _effectiveAllocation(vault, user);
        userState.allocation = effectiveAllocation;

        if (newShares > 0) {
            accounting.totalShares += newShares;
            if (effectiveAllocation == 50) {
                accounting.totalShares50 += newShares;
            } else if (effectiveAllocation == 75) {
                accounting.totalShares75 += newShares;
            }
        }

        _refreshRewardDebt(accounting, userState);

        emit UserSharesUpdated(vault, user, newShares, IERC20(vault).totalSupply());
    }

    function setYieldAllocation(address vault, uint8 percentage, address beneficiary) external {
        VaultInfo storage info = vaultInfo[vault];
        if (!info.registered) revert Errors.UnauthorizedCaller(vault);
        if (!_isValidAllocation(percentage)) revert Errors.InvalidAllocationPercentage(percentage);
        if (percentage != 100 && beneficiary == address(0)) revert Errors.InvalidBeneficiary();
        userVaultPreferences[msg.sender][vault] =
            UserYieldPreference({campaignAllocation: percentage, beneficiary: beneficiary});

        VaultAccounting storage accounting = vaultAccounting[vault];
        UserAccounting storage userState = userAccounting[vault][msg.sender];

        _settleUser(vault, accounting, userState, msg.sender);

        uint8 previousAllocation = userState.allocation;
        if (!_isValidAllocation(previousAllocation)) previousAllocation = 100;
        if (userState.shares > 0) {
            if (previousAllocation == 50) {
                accounting.totalShares50 -= userState.shares;
            } else if (previousAllocation == 75) {
                accounting.totalShares75 -= userState.shares;
            }
        }

        userState.allocation = percentage;

        if (userState.shares > 0) {
            if (percentage == 50) {
                accounting.totalShares50 += userState.shares;
            } else if (percentage == 75) {
                accounting.totalShares75 += userState.shares;
            }
        }

        _refreshRewardDebt(accounting, userState);

        emit YieldPreferenceUpdated(msg.sender, vault, percentage, beneficiary);
    }

    function getUserYieldPreference(address user, address vault) external view returns (UserYieldPreference memory) {
        return userVaultPreferences[user][vault];
    }

    /// @notice Allows supporters to claim their personal yield portion.
    function claimPersonalYield(address vault) external nonReentrant whenNotPaused returns (uint256 amount) {
        VaultInfo storage info = vaultInfo[vault];
        if (!info.registered) revert Errors.UnauthorizedCaller(vault);

        VaultAccounting storage accounting = vaultAccounting[vault];
        UserAccounting storage userState = userAccounting[vault][msg.sender];

        _settleUser(vault, accounting, userState, msg.sender);

        amount = userState.pendingPersonal;
        if (amount == 0) return 0;

        userState.pendingPersonal = 0;

        UserYieldPreference memory pref = userVaultPreferences[msg.sender][vault];
        address beneficiary = pref.beneficiary;
        if (beneficiary == address(0)) beneficiary = msg.sender;

        IERC20(info.asset).safeTransfer(beneficiary, amount);

        emit PersonalYieldClaimed(vault, msg.sender, beneficiary, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                PAYOUT LOGIC
    //////////////////////////////////////////////////////////////*/

    function processScheduledPayout(address vault, address asset, uint256 totalYield)
        external
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (!authorizedSchedulers[msg.sender]) revert Errors.UnauthorizedCaller(msg.sender);
        VaultInfo memory info = vaultInfo[vault];
        if (!info.registered) revert Errors.UnauthorizedCaller(vault);

        return _executePayout(vault, info, asset, totalYield);
    }

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

        return _executePayout(msg.sender, info, asset, totalYield);
    }

    function _executePayout(address vault, VaultInfo memory info, address asset, uint256 totalYield)
        internal
        returns (uint256)
    {
        CampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(info.campaignId);
        if (campaign.status != RegistryTypes.CampaignStatus.Active) revert Errors.CampaignNotActive();

        if (asset != info.asset) revert Errors.InvalidAsset();

        IERC20 token = IERC20(asset);
        // Round up protocol fee to favor protocol by 1 wei if there's a remainder
        uint256 protocolFee = (totalYield * protocolFeeBps + BASIS_POINTS - 1) / BASIS_POINTS;
        uint256 distributable = totalYield - protocolFee;

        if (protocolFee > 0) {
            token.safeTransfer(protocolTreasury, protocolFee);
        }

        uint256 campaignPortion = 0;

        VaultAccounting storage accounting = vaultAccounting[vault];
        uint256 totalShares = accounting.totalShares;

        if (totalShares == 0 || distributable == 0) {
            campaignPortion = distributable;
        } else {
            uint256 personalAccounted;

            if (accounting.totalShares50 > 0) {
                uint256 bucketPortion50 = (distributable * accounting.totalShares50 * 50) / (totalShares * 100);
                if (bucketPortion50 > 0) {
                    accounting.accPersonalPerShare50 += (bucketPortion50 * ACC_PRECISION) / accounting.totalShares50;
                    personalAccounted += bucketPortion50;
                }
            }

            if (accounting.totalShares75 > 0) {
                uint256 bucketPortion75 = (distributable * accounting.totalShares75 * 25) / (totalShares * 100);
                if (bucketPortion75 > 0) {
                    accounting.accPersonalPerShare75 += (bucketPortion75 * ACC_PRECISION) / accounting.totalShares75;
                    personalAccounted += bucketPortion75;
                }
            }

            campaignPortion = distributable - personalAccounted;
        }

        if (campaignPortion > 0) {
            token.safeTransfer(campaign.payout, campaignPortion);
        }

        emit CampaignPayout(
            vault,
            info.campaignId,
            info.strategyId,
            asset,
            totalYield,
            protocolFee,
            campaignPortion,
            block.timestamp,
            campaign.payout
        );

        return totalYield;
    }

    function _isValidAllocation(uint8 percentage) internal pure returns (bool) {
        return percentage == 50 || percentage == 75 || percentage == 100;
    }

    function _settleUser(
        address vault,
        VaultAccounting storage accounting,
        UserAccounting storage userState,
        address user
    ) internal {
        if (userState.allocation == 0) {
            userState.allocation = _effectiveAllocation(vault, user);
        }

        if (userState.shares == 0) {
            userState.rewardDebt = 0;
            return;
        }

        uint256 accPersonal = _getAccPersonalPerShare(accounting, userState.allocation);
        if (accPersonal == 0) {
            userState.rewardDebt = 0;
            return;
        }

        uint256 accumulated = (userState.shares * accPersonal) / ACC_PRECISION;
        if (accumulated > userState.rewardDebt) {
            userState.pendingPersonal += accumulated - userState.rewardDebt;
        }

        userState.rewardDebt = accumulated;
    }

    function _refreshRewardDebt(VaultAccounting storage accounting, UserAccounting storage userState) internal {
        if (userState.shares == 0) {
            userState.rewardDebt = 0;
            return;
        }

        uint256 accPersonal = _getAccPersonalPerShare(accounting, userState.allocation);
        userState.rewardDebt = (userState.shares * accPersonal) / ACC_PRECISION;
    }

    function _getAccPersonalPerShare(VaultAccounting storage accounting, uint8 allocation)
        internal
        view
        returns (uint256)
    {
        if (allocation == 50) {
            return accounting.accPersonalPerShare50;
        }
        if (allocation == 75) {
            return accounting.accPersonalPerShare75;
        }
        return 0;
    }

    function _effectiveAllocation(address vault, address user) internal view returns (uint8) {
        UserYieldPreference memory pref = userVaultPreferences[user][vault];
        if (_isValidAllocation(pref.campaignAllocation)) {
            return pref.campaignAllocation;
        }
        return 100;
    }
}
