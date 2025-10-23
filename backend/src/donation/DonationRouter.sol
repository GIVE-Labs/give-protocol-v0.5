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
import "./NGORegistry.sol";

contract DonationRouter is Initializable, UUPSUpgradeable, ACLShim, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 public constant PROTOCOL_FEE_BPS = 250; // 2.5%

    event DonationDistributed(
        address indexed asset, address indexed ngo, uint256 amount, uint256 feeAmount, uint256 distributionId
    );
    event UserYieldDistributed(
        address indexed user,
        address indexed asset,
        address indexed ngo,
        uint256 ngoAmount,
        uint256 treasuryAmount,
        uint256 protocolAmount
    );
    event UserPreferenceUpdated(address indexed user, address indexed ngo, uint8 allocationPercentage);
    event UserSharesUpdated(address indexed user, address indexed asset, uint256 shares, uint256 totalShares);
    event FeeCollected(address indexed asset, address indexed recipient, uint256 amount);
    event ProtocolFeeCollected(address indexed asset, uint256 amount);
    event FeeConfigUpdated(
        address indexed oldRecipient, address indexed newRecipient, uint256 oldFeeBps, uint256 newFeeBps
    );
    event ProtocolTreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event EmergencyWithdrawal(address indexed asset, address indexed recipient, uint256 amount);

    modifier onlyAuthorized() {
        if (!_state().authorizedCallers[msg.sender]) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        _;
    }

    function initialize(
        address acl,
        address registry_,
        address feeRecipient_,
        address protocolTreasury_,
        uint256 feeBps_
    ) external initializer {
        if (
            acl == address(0) || registry_ == address(0) || feeRecipient_ == address(0)
                || protocolTreasury_ == address(0)
        ) {
            revert Errors.ZeroAddress();
        }
        if (feeBps_ > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        _setACLManager(acl);

        GiveTypes.DonationRouterState storage s = _state();
        s.registry = registry_;
        s.feeRecipient = feeRecipient_;
        s.protocolTreasury = protocolTreasury_;
        s.feeBps = feeBps_;
        s.validAllocations[0] = 50;
        s.validAllocations[1] = 75;
        s.validAllocations[2] = 100;
    }

    // ===== View helpers =====

    function registry() public view returns (address) {
        return _state().registry;
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

    function totalProtocolFees(address asset) external view returns (uint256) {
        return _state().totalProtocolFees[asset];
    }

    function totalDonated(address asset) external view returns (uint256) {
        return _state().totalDonated[asset];
    }

    function authorizedCallers(address caller) external view returns (bool) {
        return _state().authorizedCallers[caller];
    }

    function getUsersWithShares(address asset) external view returns (address[] memory) {
        GiveTypes.DonationRouterState storage s = _state();
        address[] storage users = s.usersWithShares[asset];
        address[] memory copy = new address[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            copy[i] = users[i];
        }
        return copy;
    }

    function getUserPreference(address user) external view returns (GiveTypes.UserPreference memory preference) {
        preference = _state().userPreferences[user];
    }

    function getFeeConfig() external view returns (address recipient, uint256 bps, uint256 maxBps) {
        GiveTypes.DonationRouterState storage s = _state();
        return (s.feeRecipient, s.feeBps, MAX_FEE_BPS);
    }

    function getValidAllocations() external view returns (uint8[3] memory allocations) {
        allocations = _state().validAllocations;
    }

    // ===== Role-managed configuration =====

    function setAuthorizedCaller(address caller, bool authorized) external onlyRole(VAULT_MANAGER_ROLE) {
        if (caller == address(0)) revert Errors.ZeroAddress();
        _state().authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    function updateFeeConfig(address newRecipient, uint256 newFeeBps) external onlyRole(FEE_MANAGER_ROLE) {
        if (newRecipient == address(0)) revert Errors.ZeroAddress();
        if (newFeeBps > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        GiveTypes.DonationRouterState storage s = _state();
        address oldRecipient = s.feeRecipient;
        uint256 oldBps = s.feeBps;

        s.feeRecipient = newRecipient;
        s.feeBps = newFeeBps;

        emit FeeConfigUpdated(oldRecipient, newRecipient, oldBps, newFeeBps);
    }

    function setProtocolTreasury(address newTreasury) external onlyRole(FEE_MANAGER_ROLE) {
        if (newTreasury == address(0)) revert Errors.ZeroAddress();
        GiveTypes.DonationRouterState storage s = _state();
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

    // ===== User Preferences =====

    function setUserPreference(address selectedNGO, uint8 allocationPercentage) external whenNotPaused {
        GiveTypes.DonationRouterState storage s = _state();
        if (!NGORegistry(s.registry).isApproved(selectedNGO)) {
            revert Errors.NGONotApproved();
        }
        if (!_isValidAllocation(allocationPercentage)) {
            revert Errors.InvalidAllocationPercentage(allocationPercentage);
        }

        s.userPreferences[msg.sender] = GiveTypes.UserPreference({
            selectedNGO: selectedNGO,
            allocationPercentage: allocationPercentage,
            lastUpdated: block.timestamp
        });

        emit UserPreferenceUpdated(msg.sender, selectedNGO, allocationPercentage);
    }

    function calculateUserDistribution(address user, uint256 userYield)
        public
        view
        returns (uint256 ngoAmount, uint256 treasuryAmount, uint256 protocolAmount)
    {
        if (userYield == 0) return (0, 0, 0);

        GiveTypes.DonationRouterState storage s = _state();
        protocolAmount = (userYield * PROTOCOL_FEE_BPS) / 10_000;
        uint256 netYield = userYield - protocolAmount;

        GiveTypes.UserPreference memory pref = s.userPreferences[user];
        if (pref.selectedNGO == address(0) || !NGORegistry(s.registry).isApproved(pref.selectedNGO)) {
            ngoAmount = 0;
            treasuryAmount = netYield;
        } else {
            ngoAmount = (netYield * pref.allocationPercentage) / 100;
            treasuryAmount = netYield - ngoAmount;
        }
    }

    // ===== Share Tracking =====

    function updateUserShares(address user, address asset, uint256 newShares) external onlyAuthorized {
        GiveTypes.DonationRouterState storage s = _state();
        uint256 oldShares = s.userAssetShares[user][asset];
        s.userAssetShares[user][asset] = newShares;
        s.totalAssetShares[asset] = s.totalAssetShares[asset] - oldShares + newShares;

        if (oldShares == 0 && newShares > 0) {
            if (!s.hasShares[asset][user]) {
                s.usersWithShares[asset].push(user);
                s.hasShares[asset][user] = true;
            }
        } else if (oldShares > 0 && newShares == 0) {
            if (s.hasShares[asset][user]) {
                _removeUserWithShares(s, asset, user);
                s.hasShares[asset][user] = false;
            }
        }

        emit UserSharesUpdated(user, asset, newShares, s.totalAssetShares[asset]);
    }

    function getUserAssetShares(address user, address asset) external view returns (uint256) {
        return _state().userAssetShares[user][asset];
    }

    function getTotalAssetShares(address asset) external view returns (uint256) {
        return _state().totalAssetShares[asset];
    }

    // Backwards-compatible getters
    function userAssetShares(address user, address asset) external view returns (uint256) {
        return _state().userAssetShares[user][asset];
    }

    function totalAssetShares(address asset) external view returns (uint256) {
        return _state().totalAssetShares[asset];
    }

    // ===== Distribution Functions =====

    function distributeToAllUsers(address asset, uint256 totalYield)
        external
        nonReentrant
        whenNotPaused
        onlyAuthorized
        returns (uint256)
    {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (totalYield == 0) revert Errors.InvalidAmount();

        IERC20 token = IERC20(asset);
        if (token.balanceOf(address(this)) < totalYield) revert Errors.InsufficientBalance();

        GiveTypes.DonationRouterState storage s = _state();
        uint256 totalShares = s.totalAssetShares[asset];
        if (totalShares == 0) {
            return _legacyDistribute(asset, totalYield, token, s);
        }

        address[] storage users = s.usersWithShares[asset];
        YieldTotals memory totals;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 userShares = s.userAssetShares[user][asset];
            if (userShares == 0) continue;

            uint256 userYield = (totalYield * userShares) / totalShares;
            if (userYield == 0) continue;

            (uint256 ngoAmount, uint256 treasuryAmount, uint256 protocolAmount) =
                calculateUserDistribution(user, userYield);

            totals.ngo += ngoAmount;
            totals.treasury += treasuryAmount;
            totals.protocol += protocolAmount;

            emit UserYieldDistributed(
                user, asset, _state().userPreferences[user].selectedNGO, ngoAmount, treasuryAmount, protocolAmount
            );
        }

        if (totals.protocol > 0) {
            token.safeTransfer(s.protocolTreasury, totals.protocol);
            s.totalProtocolFees[asset] += totals.protocol;
            emit ProtocolFeeCollected(asset, totals.protocol);
        }

        if (totals.ngo > 0) {
            _distributeToNGOs(asset, totalYield, totalShares, users, token, s);
        }

        if (totals.treasury > 0) {
            token.safeTransfer(s.feeRecipient, totals.treasury);
            s.totalFeeCollected[asset] += totals.treasury;
        }

        s.totalDistributions++;
        return totals.ngo + totals.treasury + totals.protocol;
    }

    function distribute(address asset, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyAuthorized
        returns (uint256 netDonation, uint256 feeAmount)
    {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();

        GiveTypes.DonationRouterState storage s = _state();

        IERC20 token = IERC20(asset);
        if (token.balanceOf(address(this)) < amount) revert Errors.InsufficientBalance();

        address currentNGO = NGORegistry(s.registry).currentNGO();
        if (currentNGO == address(0)) revert Errors.NoNGOConfigured();
        if (!NGORegistry(s.registry).isApproved(currentNGO)) revert Errors.NGONotApproved();

        feeAmount = (amount * s.feeBps) / 10_000;
        netDonation = amount - feeAmount;

        if (feeAmount > 0) {
            token.safeTransfer(s.feeRecipient, feeAmount);
            s.totalFeeCollected[asset] += feeAmount;
            emit FeeCollected(asset, s.feeRecipient, feeAmount);
        }

        if (netDonation > 0) {
            token.safeTransfer(currentNGO, netDonation);
            s.totalDonated[asset] += netDonation;
            NGORegistry(s.registry).recordDonation(currentNGO, netDonation);
        }

        s.totalDistributions++;
        emit DonationDistributed(asset, currentNGO, netDonation, feeAmount, s.totalDistributions);
        return (netDonation, feeAmount);
    }

    function distributeToMultiple(address asset, uint256 amount, address[] calldata ngos)
        external
        nonReentrant
        whenNotPaused
        onlyAuthorized
        returns (uint256 totalNetDonation, uint256 feeAmount)
    {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();
        if (ngos.length == 0) revert Errors.InvalidConfiguration();

        GiveTypes.DonationRouterState storage s = _state();
        IERC20 token = IERC20(asset);
        if (token.balanceOf(address(this)) < amount) revert Errors.InsufficientBalance();

        _validateNGOList(s, ngos);

        DonationSplit memory split;
        split.feeAmount = (amount * s.feeBps) / 10_000;
        split.netDonation = amount - split.feeAmount;

        if (split.netDonation > 0) {
            split.amountPerNGO = split.netDonation / ngos.length;
            split.remainder = split.netDonation % ngos.length;
        }

        if (split.feeAmount > 0) {
            token.safeTransfer(s.feeRecipient, split.feeAmount);
            s.totalFeeCollected[asset] += split.feeAmount;
            emit FeeCollected(asset, s.feeRecipient, split.feeAmount);
        }

        if (split.netDonation > 0) {
            _distributeInEqualParts(asset, token, ngos, split, s);
        }

        totalNetDonation = split.netDonation;
        feeAmount = split.feeAmount;
    }

    // ===== Emergency =====

    function emergencyWithdraw(address asset, address recipient, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (asset == address(0) || recipient == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();

        IERC20 token = IERC20(asset);
        if (token.balanceOf(address(this)) < amount) revert Errors.InsufficientBalance();

        token.safeTransfer(recipient, amount);
        emit EmergencyWithdrawal(asset, recipient, amount);
    }

    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    // ===== Internal helpers =====

    function _legacyDistribute(address asset, uint256 totalYield, IERC20 token, GiveTypes.DonationRouterState storage s)
        private
        returns (uint256)
    {
        address currentNGO = NGORegistry(s.registry).currentNGO();
        if (currentNGO == address(0) || !NGORegistry(s.registry).isApproved(currentNGO)) {
            token.safeTransfer(s.feeRecipient, totalYield);
            return totalYield;
        }

        uint256 feeAmount = (totalYield * s.feeBps) / 10_000;
        uint256 netDonation = totalYield - feeAmount;

        if (netDonation > 0) {
            token.safeTransfer(currentNGO, netDonation);
            s.totalDonated[asset] += netDonation;
            NGORegistry(s.registry).recordDonation(currentNGO, netDonation);
        }

        if (feeAmount > 0) {
            token.safeTransfer(s.feeRecipient, feeAmount);
            s.totalFeeCollected[asset] += feeAmount;
            emit FeeCollected(asset, s.feeRecipient, feeAmount);
        }

        s.totalDistributions++;
        emit DonationDistributed(asset, currentNGO, netDonation, feeAmount, s.totalDistributions);
        return totalYield;
    }

    struct DonationSplit {
        uint256 amountPerNGO;
        uint256 remainder;
        uint256 netDonation;
        uint256 feeAmount;
    }

    struct YieldTotals {
        uint256 ngo;
        uint256 treasury;
        uint256 protocol;
    }

    function _distributeToNGOs(
        address asset,
        uint256 totalYield,
        uint256 totalShares,
        address[] storage users,
        IERC20 token,
        GiveTypes.DonationRouterState storage s
    ) private {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 userShares = s.userAssetShares[user][asset];
            if (userShares == 0) continue;

            GiveTypes.UserPreference memory pref = s.userPreferences[user];
            if (pref.selectedNGO == address(0) || !NGORegistry(s.registry).isApproved(pref.selectedNGO)) continue;

            uint256 userYield = (totalYield * userShares) / totalShares;
            (uint256 ngoAmount,,) = calculateUserDistribution(user, userYield);
            if (ngoAmount == 0) continue;

            token.safeTransfer(pref.selectedNGO, ngoAmount);
            s.totalDonated[asset] += ngoAmount;
            NGORegistry(s.registry).recordDonation(pref.selectedNGO, ngoAmount);
        }
    }

    function _validateNGOList(GiveTypes.DonationRouterState storage s, address[] calldata ngos) private view {
        for (uint256 i = 0; i < ngos.length; i++) {
            if (!NGORegistry(s.registry).isApproved(ngos[i])) revert Errors.NGONotApproved();
        }
    }

    function _distributeInEqualParts(
        address asset,
        IERC20 token,
        address[] calldata ngos,
        DonationSplit memory split,
        GiveTypes.DonationRouterState storage s
    ) private {
        uint256 length = ngos.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 donationAmount = split.amountPerNGO;
            if (i == 0) donationAmount += split.remainder;
            if (donationAmount == 0) continue;

            address ngo = ngos[i];
            token.safeTransfer(ngo, donationAmount);
            s.totalDonated[asset] += donationAmount;
            NGORegistry(s.registry).recordDonation(ngo, donationAmount);

            s.totalDistributions++;
            emit DonationDistributed(asset, ngo, donationAmount, i == 0 ? split.feeAmount : 0, s.totalDistributions);
        }
    }

    function _removeUserWithShares(GiveTypes.DonationRouterState storage s, address asset, address user) private {
        address[] storage users = s.usersWithShares[asset];
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                users[i] = users[users.length - 1];
                users.pop();
                break;
            }
        }
    }

    function _isValidAllocation(uint8 allocation) private view returns (bool) {
        GiveTypes.DonationRouterState storage s = _state();
        for (uint256 i = 0; i < s.validAllocations.length; i++) {
            if (s.validAllocations[i] == allocation) {
                return true;
            }
        }
        return false;
    }

    function _state() private view returns (GiveTypes.DonationRouterState storage) {
        return StorageLib.donationRouter();
    }

    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
    }
}
