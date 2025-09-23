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

    /// @notice User yield allocation preference per vault
    struct UserYieldPreference {
        uint8 campaignAllocation; // 50, 75, or 100
        address beneficiary; // recipient for remaining yield
    }

    CampaignRegistry public immutable campaignRegistry;
    address public protocolTreasury;

    uint256 public epochDuration = 7 days;

    bytes32 public immutable TREASURY_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;
    bytes32 public immutable CAMPAIGN_ADMIN_ROLE;

    mapping(address => VaultInfo) public vaultInfo;
    mapping(address => bool) public authorizedCallers;
    mapping(address => bool) public authorizedSchedulers;
    mapping(address => mapping(address => UserYieldPreference)) public userVaultPreferences;
    mapping(address => mapping(address => uint256)) public userVaultShares;
    mapping(address => address[]) private vaultShareholders;
    mapping(address => mapping(address => uint256)) private shareholderIndex; // 1-based index

    event UserSharesUpdated(address indexed vault, address indexed user, uint256 shares, uint256 totalShares);
    event YieldPreferenceUpdated(address indexed user, address indexed vault, uint8 campaignAllocation, address beneficiary);
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
    event SchedulerAuthorizationUpdated(address indexed scheduler, bool authorized);

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

    function setScheduler(address scheduler, bool authorized) external onlyRole(CAMPAIGN_ADMIN_ROLE) {
        authorizedSchedulers[scheduler] = authorized;
        emit SchedulerAuthorizationUpdated(scheduler, authorized);
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

    /// @notice Vaults update supporter share balances for allocation calculations.
    function updateUserShares(address user, address vault, uint256 newShares) external {
        if (msg.sender != vault) revert Errors.UnauthorizedCaller(msg.sender);
        if (!vaultInfo[vault].registered) revert Errors.UnauthorizedCaller(vault);

        uint256 actual = IERC20(vault).balanceOf(user);
        require(actual == newShares, "shares mismatch");

        uint256 previous = userVaultShares[user][vault];
        userVaultShares[user][vault] = newShares;

        uint256 idx = shareholderIndex[vault][user];
        if (newShares > 0) {
            if (idx == 0) {
                vaultShareholders[vault].push(user);
                shareholderIndex[vault][user] = vaultShareholders[vault].length;
            }
        } else if (previous > 0 && idx != 0) {
            uint256 last = vaultShareholders[vault].length;
            if (idx != last) {
                address lastUser = vaultShareholders[vault][last - 1];
                vaultShareholders[vault][idx - 1] = lastUser;
                shareholderIndex[vault][lastUser] = idx;
            }
            vaultShareholders[vault].pop();
            shareholderIndex[vault][user] = 0;
        }

        emit UserSharesUpdated(vault, user, newShares, IERC20(vault).totalSupply());
    }

    function setYieldAllocation(address vault, uint8 percentage, address beneficiary) external {
        if (!vaultInfo[vault].registered) revert Errors.UnauthorizedCaller(vault);
        if (!_isValidAllocation(percentage)) revert Errors.InvalidAllocationPercentage(percentage);
        userVaultPreferences[msg.sender][vault] = UserYieldPreference({campaignAllocation: percentage, beneficiary: beneficiary});
        emit YieldPreferenceUpdated(msg.sender, vault, percentage, beneficiary);
    }

    function getUserYieldPreference(address user, address vault) external view returns (UserYieldPreference memory) {
        return userVaultPreferences[user][vault];
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

        IERC20 token = IERC20(asset);
        uint256 protocolFee = (totalYield * PROTOCOL_FEE_BPS) / BASIS_POINTS;
        uint256 distributable = totalYield - protocolFee;

        if (protocolFee > 0) {
            token.safeTransfer(protocolTreasury, protocolFee);
        }

        uint256 campaignPortion = 0;
        uint256 totalShares = IERC20(vault).totalSupply();
        uint256 remaining = distributable;

        address[] storage holders = vaultShareholders[vault];
        uint256 length = holders.length;
        address[] memory payees = new address[](length);
        uint256[] memory payeeAmounts = new uint256[](length);
        uint256 payeeCount;

        if (totalShares == 0 || distributable == 0) {
            campaignPortion = distributable;
            remaining = 0;
        } else {
            for (uint256 i; i < length; ++i) {
                address user = holders[i];
                uint256 idx = shareholderIndex[vault][user];
                if (idx == 0) continue;

                uint256 shares = userVaultShares[user][vault];
                if (shares == 0) continue;

                uint256 userPortion = (distributable * shares) / totalShares;
                if (userPortion == 0) continue;

                UserYieldPreference memory pref = userVaultPreferences[user][vault];
                uint8 allocation = pref.campaignAllocation;
                if (!_isValidAllocation(allocation)) allocation = 100;

                uint256 toCampaign = (userPortion * allocation) / 100;
                campaignPortion += toCampaign;

                uint256 remainder = userPortion - toCampaign;
                if (remainder > 0) {
                    address beneficiary = pref.beneficiary;
                    if (beneficiary == address(0)) beneficiary = user;
                    payees[payeeCount] = beneficiary;
                    payeeAmounts[payeeCount] = remainder;
                    payeeCount++;
                }

                if (remaining > userPortion) {
                    remaining -= userPortion;
                } else {
                    remaining = 0;
                }
            }

            if (remaining > 0) {
                campaignPortion += remaining;
                remaining = 0;
            }
        }

        if (campaignPortion > 0) {
            token.safeTransfer(campaign.payout, campaignPortion);
        }

        for (uint256 j; j < payeeCount; ++j) {
            uint256 amount = payeeAmounts[j];
            if (amount == 0) continue;
            token.safeTransfer(payees[j], amount);
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
}
