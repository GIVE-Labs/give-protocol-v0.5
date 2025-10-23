// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";
import "../utils/Errors.sol";
import "../utils/ACLShim.sol";
import "../registry/CampaignRegistry.sol";

/// @title PayoutRouter
/// @notice Campaign-aware router that distributes harvested yield between campaigns, supporters, and protocol.
contract PayoutRouter is
    Initializable,
    UUPSUpgradeable,
    ACLShim,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_MANAGER_ROLE =
        keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    uint256 public constant MAX_FEE_BPS = 1_000; // 10%
    uint256 public constant PROTOCOL_FEE_BPS = 250; // 2.5%

    event YieldPreferenceUpdated(
        address indexed user,
        address indexed vault,
        bytes32 indexed campaignId,
        address beneficiary,
        uint8 allocationPercentage
    );
    event UserSharesUpdated(
        address indexed user,
        address indexed vault,
        uint256 shares,
        uint256 totalShares
    );
    event CampaignVaultRegistered(
        address indexed vault,
        bytes32 indexed campaignId
    );
    event CampaignPayoutExecuted(
        bytes32 indexed campaignId,
        address indexed vault,
        address recipient,
        uint256 campaignAmount,
        uint256 protocolAmount
    );
    event BeneficiaryPaid(
        address indexed user,
        address indexed vault,
        address beneficiary,
        uint256 amount
    );
    event FeeConfigUpdated(
        address indexed oldRecipient,
        address indexed newRecipient,
        uint256 oldFeeBps,
        uint256 newFeeBps
    );
    event ProtocolTreasuryUpdated(
        address indexed oldTreasury,
        address indexed newTreasury
    );
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event EmergencyWithdrawal(
        address indexed asset,
        address indexed recipient,
        uint256 amount
    );

    error Unauthorized(bytes32 roleId, address account);
    error VaultNotRegistered(address vault);
    error InvalidAllocation(uint8 allocation);
    error InvalidBeneficiary();
    error CampaignMismatch(bytes32 expected, bytes32 provided);

    struct YieldTotals {
        uint256 campaign;
        uint256 beneficiary;
        uint256 protocol;
    }

    function initialize(
        address acl_,
        address campaignRegistry_,
        address feeRecipient_,
        address protocolTreasury_,
        uint256 feeBps_
    ) external initializer {
        if (
            acl_ == address(0) ||
            campaignRegistry_ == address(0) ||
            feeRecipient_ == address(0) ||
            protocolTreasury_ == address(0)
        ) {
            revert Errors.ZeroAddress();
        }
        if (feeBps_ > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        _setACLManager(acl_);

        GiveTypes.PayoutRouterState storage s = _state();
        s.campaignRegistry = campaignRegistry_;
        s.feeRecipient = feeRecipient_;
        s.protocolTreasury = protocolTreasury_;
        s.feeBps = feeBps_;
        s.validAllocations[0] = 50;
        s.validAllocations[1] = 75;
        s.validAllocations[2] = 100;
    }

    // ===== View helpers =====

    function campaignRegistry() public view returns (address) {
        return _state().campaignRegistry;
    }

    function feeRecipient() public view returns (address) {
        return _state().feeRecipient;
    }

    function protocolTreasury() public view returns (address) {
        return _state().protocolTreasury;
    }

    function feeBps() public view returns (uint256) {
        return _state().feeBps;
    }

    function totalDistributions() external view returns (uint256) {
        return _state().totalDistributions;
    }

    function authorizedCallers(address caller) external view returns (bool) {
        return _state().authorizedCallers[caller];
    }

    function getValidAllocations() external view returns (uint8[3] memory) {
        return _state().validAllocations;
    }

    function getVaultCampaign(address vault) external view returns (bytes32) {
        return _state().vaultCampaigns[vault];
    }

    function getVaultPreference(
        address user,
        address vault
    ) external view returns (GiveTypes.CampaignPreference memory) {
        return _state().userPreferences[user][vault];
    }

    function getUserVaultShares(
        address user,
        address vault
    ) external view returns (uint256) {
        return _state().userVaultShares[user][vault];
    }

    function getTotalVaultShares(
        address vault
    ) external view returns (uint256) {
        return _state().totalVaultShares[vault];
    }

    function getVaultShareholders(
        address vault
    ) external view returns (address[] memory) {
        GiveTypes.PayoutRouterState storage s = _state();
        address[] storage list = s.vaultShareholders[vault];
        address[] memory copy = new address[](list.length);
        for (uint256 i = 0; i < list.length; i++) {
            copy[i] = list[i];
        }
        return copy;
    }

    function getCampaignTotals(
        bytes32 campaignId
    ) external view returns (uint256 payouts, uint256 protocolFees) {
        GiveTypes.PayoutRouterState storage s = _state();
        return (
            s.campaignTotalPayouts[campaignId],
            s.campaignProtocolFees[campaignId]
        );
    }

    // ===== Role-managed configuration =====

    function setAuthorizedCaller(
        address caller,
        bool authorized
    ) external onlyRole(VAULT_MANAGER_ROLE) {
        if (caller == address(0)) revert Errors.ZeroAddress();
        _state().authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    function updateFeeConfig(
        address newRecipient,
        uint256 newFeeBps
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (newRecipient == address(0)) revert Errors.ZeroAddress();
        if (newFeeBps > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        GiveTypes.PayoutRouterState storage s = _state();
        address oldRecipient = s.feeRecipient;
        uint256 oldBps = s.feeBps;

        s.feeRecipient = newRecipient;
        s.feeBps = newFeeBps;

        emit FeeConfigUpdated(oldRecipient, newRecipient, oldBps, newFeeBps);
    }

    function setProtocolTreasury(
        address newTreasury
    ) external onlyRole(FEE_MANAGER_ROLE) {
        if (newTreasury == address(0)) revert Errors.ZeroAddress();
        GiveTypes.PayoutRouterState storage s = _state();
        address oldTreasury = s.protocolTreasury;
        s.protocolTreasury = newTreasury;
        emit ProtocolTreasuryUpdated(oldTreasury, newTreasury);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ===== Campaign wiring =====

    function registerCampaignVault(
        address vault,
        bytes32 campaignId
    ) external onlyRole(VAULT_MANAGER_ROLE) {
        if (vault == address(0) || campaignId == bytes32(0))
            revert Errors.ZeroAddress();
        GiveTypes.PayoutRouterState storage s = _state();
        s.vaultCampaigns[vault] = campaignId;
        emit CampaignVaultRegistered(vault, campaignId);
    }

    // ===== Preferences =====

    function setVaultPreference(
        address vault,
        address beneficiary,
        uint8 allocationPercentage
    ) external whenNotPaused {
        GiveTypes.PayoutRouterState storage s = _state();
        bytes32 campaignId = _requireCampaignForVault(s, vault);

        if (!_isValidAllocation(s, allocationPercentage))
            revert InvalidAllocation(allocationPercentage);
        if (allocationPercentage < 100 && beneficiary == address(0))
            revert InvalidBeneficiary();

        GiveTypes.CampaignPreference storage pref = s.userPreferences[
            msg.sender
        ][vault];
        pref.campaignId = campaignId;
        pref.beneficiary = beneficiary;
        pref.allocationPercentage = allocationPercentage;
        pref.lastUpdated = block.timestamp;

        emit YieldPreferenceUpdated(
            msg.sender,
            vault,
            campaignId,
            beneficiary,
            allocationPercentage
        );
    }

    // ===== Share tracking =====

    function updateUserShares(
        address user,
        address vault,
        uint256 newShares
    ) external onlyAuthorized {
        GiveTypes.PayoutRouterState storage s = _state();
        uint256 oldShares = s.userVaultShares[user][vault];
        s.userVaultShares[user][vault] = newShares;
        s.totalVaultShares[vault] =
            s.totalVaultShares[vault] -
            oldShares +
            newShares;

        if (oldShares == 0 && newShares > 0) {
            if (!s.hasVaultShare[vault][user]) {
                s.vaultShareholders[vault].push(user);
                s.hasVaultShare[vault][user] = true;
            }
        } else if (oldShares > 0 && newShares == 0) {
            if (s.hasVaultShare[vault][user]) {
                _removeShareholder(s, vault, user);
                s.hasVaultShare[vault][user] = false;
            }
        }

        emit UserSharesUpdated(
            user,
            vault,
            newShares,
            s.totalVaultShares[vault]
        );
    }

    // ===== Yield distribution =====

    function distributeToAllUsers(
        address asset,
        uint256 totalYield
    ) external nonReentrant whenNotPaused onlyAuthorized returns (uint256) {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (totalYield == 0) revert Errors.InvalidAmount();

        IERC20 token = IERC20(asset);
        if (token.balanceOf(address(this)) < totalYield)
            revert Errors.InsufficientBalance();

        GiveTypes.PayoutRouterState storage s = _state();
        bytes32 campaignId = _requireCampaignForVault(s, msg.sender);
        GiveTypes.CampaignConfig memory campaign = CampaignRegistry(
            s.campaignRegistry
        ).getCampaign(campaignId);
        if (campaign.payoutsHalted) revert Errors.OperationNotAllowed();

        uint256 totalShares = s.totalVaultShares[msg.sender];
        if (totalShares == 0) revert Errors.InvalidConfiguration();

        address[] storage holders = s.vaultShareholders[msg.sender];
        YieldTotals memory totals;

        for (uint256 i = 0; i < holders.length; i++) {
            address user = holders[i];
            uint256 userShares = s.userVaultShares[user][msg.sender];
            if (userShares == 0) continue;

            uint256 userYield = (totalYield * userShares) / totalShares;
            if (userYield == 0) continue;

            (
                uint256 campaignAmount,
                uint256 beneficiaryAmount,
                uint256 protocolAmount,
                address beneficiary
            ) = _calculateAllocations(
                    s,
                    campaignId,
                    campaign.payoutRecipient,
                    user,
                    msg.sender,
                    userYield
                );

            totals.campaign += campaignAmount;
            totals.beneficiary += beneficiaryAmount;
            totals.protocol += protocolAmount;

            if (beneficiaryAmount > 0) {
                token.safeTransfer(beneficiary, beneficiaryAmount);
                emit BeneficiaryPaid(
                    user,
                    msg.sender,
                    beneficiary,
                    beneficiaryAmount
                );
            }
        }

        if (totals.protocol > 0) {
            token.safeTransfer(s.protocolTreasury, totals.protocol);
            s.campaignProtocolFees[campaignId] += totals.protocol;
        }

        if (totals.campaign > 0) {
            token.safeTransfer(campaign.payoutRecipient, totals.campaign);
            s.campaignTotalPayouts[campaignId] += totals.campaign;
        }

        s.totalDistributions += 1;

        emit CampaignPayoutExecuted(
            campaignId,
            msg.sender,
            campaign.payoutRecipient,
            totals.campaign,
            totals.protocol
        );

        return totals.campaign + totals.beneficiary + totals.protocol;
    }

    function emergencyWithdraw(
        address asset,
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (asset == address(0) || recipient == address(0))
            revert Errors.ZeroAddress();
        IERC20(asset).safeTransfer(recipient, amount);
        emit EmergencyWithdrawal(asset, recipient, amount);
    }

    // ===== Internal helpers =====

    function _calculateAllocations(
        GiveTypes.PayoutRouterState storage s,
        bytes32 campaignId,
        address defaultBeneficiary,
        address user,
        address vault,
        uint256 userYield
    )
        private
        view
        returns (
            uint256 campaignAmount,
            uint256 beneficiaryAmount,
            uint256 protocolAmount,
            address payoutTo
        )
    {
        protocolAmount = (userYield * PROTOCOL_FEE_BPS) / 10_000;
        uint256 netYield = userYield - protocolAmount;

        GiveTypes.CampaignPreference memory pref = s.userPreferences[user][
            vault
        ];
        if (pref.campaignId != bytes32(0) && pref.campaignId != campaignId)
            revert CampaignMismatch(campaignId, pref.campaignId);

        uint8 allocation = pref.allocationPercentage == 0
            ? 100
            : pref.allocationPercentage;
        payoutTo = pref.beneficiary == address(0)
            ? defaultBeneficiary
            : pref.beneficiary;

        campaignAmount = (netYield * allocation) / 100;
        beneficiaryAmount = netYield - campaignAmount;

        if (beneficiaryAmount > 0 && payoutTo == address(0)) {
            payoutTo = s.feeRecipient;
        }
    }

    function _removeShareholder(
        GiveTypes.PayoutRouterState storage s,
        address vault,
        address user
    ) private {
        address[] storage holders = s.vaultShareholders[vault];
        uint256 length = holders.length;
        for (uint256 i = 0; i < length; i++) {
            if (holders[i] == user) {
                if (i != length - 1) {
                    holders[i] = holders[length - 1];
                }
                holders.pop();
                break;
            }
        }
    }

    function _requireCampaignForVault(
        GiveTypes.PayoutRouterState storage s,
        address vault
    ) private view returns (bytes32) {
        bytes32 campaignId = s.vaultCampaigns[vault];
        if (campaignId == bytes32(0)) revert VaultNotRegistered(vault);
        return campaignId;
    }

    function _isValidAllocation(
        GiveTypes.PayoutRouterState storage s,
        uint8 allocation
    ) private view returns (bool) {
        for (uint256 i = 0; i < s.validAllocations.length; i++) {
            if (s.validAllocations[i] == allocation) return true;
        }
        return false;
    }

    function _state()
        private
        view
        returns (GiveTypes.PayoutRouterState storage)
    {
        return StorageLib.payoutRouter();
    }

    modifier onlyAuthorized() {
        if (!_state().authorizedCallers[msg.sender]) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        _;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Unauthorized(ROLE_UPGRADER, msg.sender);
        }
    }
}
