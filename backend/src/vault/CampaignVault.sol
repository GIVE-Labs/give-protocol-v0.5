// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {GiveVault4626} from "./GiveVault4626.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {Errors} from "../utils/Errors.sol";
import {PayoutRouter} from "../payout/PayoutRouter.sol";

/// @title CampaignVault
/// @notice ERC-4626 vault variant that tracks campaign/strategy metadata and enforces lock profiles.
contract CampaignVault is GiveVault4626 {
    /// @notice Individual position tracking for independent lock management
    struct Position {
        uint256 shares;      // Number of shares from this deposit
        uint256 unlockTime;  // When this specific position unlocks
        uint256 depositTime; // When this position was created
    }

    /// @notice Linked campaign identifier.
    uint64 public immutable campaignId;
    /// @notice Linked strategy identifier.
    uint64 public immutable strategyId;
    /// @notice Lock profile used to compute unlock timestamps.
    RegistryTypes.LockProfile public immutable lockProfile;
    /// @notice Factory that deployed this vault.
    address public immutable factory;
    /// @notice Lock duration expressed in seconds.
    uint256 public immutable lockDuration;
    /// @notice Minimum deposit amount to prevent griefing attacks.
    uint256 public immutable minDepositAmount;

    /// @dev User positions with independent lock tracking
    mapping(address => Position[]) private _userPositions;

    /// @dev Reentrancy guard state for emergency transfers
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _emergencyTransferStatus = NOT_ENTERED;

    /// @notice Emitted when a new position is created
    event PositionCreated(address indexed account, uint256 indexed positionId, uint256 shares, uint256 unlockTime);
    /// @notice Emitted when a position is redeemed
    event PositionRedeemed(address indexed account, uint256 indexed positionId, uint256 shares);
    /// @notice Emitted when positions are cleared (emergency)
    event PositionsCleared(address indexed account);

    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        address roleManager_,
        uint64 campaignId_,
        uint64 strategyId_,
        RegistryTypes.LockProfile lockProfile_,
        uint256 minDepositAmount_
    ) GiveVault4626(asset, name, symbol, roleManager_) {
        campaignId = campaignId_;
        strategyId = strategyId_;
        lockProfile = lockProfile_;
        factory = msg.sender;
        lockDuration = RegistryTypes.lockDuration(lockProfile_);
        minDepositAmount = minDepositAmount_;
    }

    /// @notice Returns the next unlock timestamp for an account
    function getNextUnlockTime(address account) external view returns (uint256) {
        Position[] storage positions = _userPositions[account];
        uint256 nextUnlock = type(uint256).max;

        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].shares > 0 &&
                positions[i].unlockTime > block.timestamp &&
                positions[i].unlockTime < nextUnlock) {
                nextUnlock = positions[i].unlockTime;
            }
        }

        return nextUnlock == type(uint256).max ? 0 : nextUnlock;
    }

    /// @notice Returns the amount of shares that are currently unlocked
    function getUnlockedShares(address account) public view returns (uint256 unlocked) {
        Position[] storage positions = _userPositions[account];
        for (uint256 i = 0; i < positions.length; i++) {
            if (block.timestamp >= positions[i].unlockTime) {
                unlocked += positions[i].shares;
            }
        }
    }

    /// @notice Returns the amount of shares that are still locked
    function getLockedShares(address account) external view returns (uint256) {
        uint256 totalShares = balanceOf(account);
        uint256 unlockedShares = getUnlockedShares(account);
        return totalShares > unlockedShares ? totalShares - unlockedShares : 0;
    }

    /// @notice Returns the number of positions for an account
    function getPositionCount(address account) external view returns (uint256) {
        return _userPositions[account].length;
    }

    /// @notice Returns details of a specific position
    function getPosition(address account, uint256 index)
        external view returns (uint256 shares, uint256 unlockTime, uint256 depositTime) {
        require(index < _userPositions[account].length, "Invalid position index");
        Position memory pos = _userPositions[account][index];
        return (pos.shares, pos.unlockTime, pos.depositTime);
    }

    /// @notice Guardian utility to clear all positions (emergency scenarios)
    function clearPositions(address account) external onlyRole(roleManager.ROLE_GUARDIAN()) {
        delete _userPositions[account];
        emit PositionsCleared(account);
    }

    function _update(address from, address to, uint256 value) internal override {
        // Case 1: Transfer between users (block unless guardian/emergency)
        if (from != address(0) && to != address(0) && from != to) {
            // Block all transfers unless caller has special privileges
            if (!roleManager.hasRole(roleManager.ROLE_GUARDIAN(), msg.sender) &&
                !roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), msg.sender)) {
                revert Errors.OperationNotAllowed();
            }
            // Prevent reentrancy during emergency transfers
            require(_emergencyTransferStatus != ENTERED, "ReentrancyGuard: reentrant call");
            _emergencyTransferStatus = ENTERED;

            // In emergency, transfer positions proportionally
            _emergencyTransferPositions(from, to, value);

            _emergencyTransferStatus = NOT_ENTERED;
        }
        // Case 2: Burning (withdrawal/redemption) - handled by withdraw/redeem overrides
        // Case 3: Minting (deposit) - handled by deposit override

        super._update(from, to, value);

        // Clean up empty positions after burns
        if (from != address(0) && to == address(0)) {
            _cleanupEmptyPositions(from);
        }
    }

    /// @notice Override deposit to create a new position with independent lock
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256 shares) {
        require(assets >= minDepositAmount, "Deposit below minimum");
        shares = super.deposit(assets, receiver);

        // Create new position for this deposit
        uint256 unlockTime = block.timestamp + lockDuration;
        _userPositions[receiver].push(Position({
            shares: shares,
            unlockTime: unlockTime,
            depositTime: block.timestamp
        }));

        emit PositionCreated(receiver, _userPositions[receiver].length - 1, shares, unlockTime);

        return shares;
    }

    /// @notice Override mint to create a new position with independent lock
    function mint(uint256 shares, address receiver) public virtual override returns (uint256 assets) {
        assets = super.mint(shares, receiver);
        require(assets >= minDepositAmount, "Deposit below minimum");

        // Create new position for this mint
        uint256 unlockTime = block.timestamp + lockDuration;
        _userPositions[receiver].push(Position({
            shares: shares,
            unlockTime: unlockTime,
            depositTime: block.timestamp
        }));

        emit PositionCreated(receiver, _userPositions[receiver].length - 1, shares, unlockTime);

        return assets;
    }

    /// @notice Deposit assets on behalf of another account while respecting lock mechanics.
    function depositFor(address from, uint256 assets, address receiver)
        public
        override
        returns (uint256 shares)
    {
        require(assets >= minDepositAmount, "Deposit below minimum");
        shares = super.depositFor(from, assets, receiver);

        uint256 unlockTime = block.timestamp + lockDuration;
        _userPositions[receiver].push(Position({
            shares: shares,
            unlockTime: unlockTime,
            depositTime: block.timestamp
        }));

        emit PositionCreated(receiver, _userPositions[receiver].length - 1, shares, unlockTime);

        return shares;
    }

    /// @notice Override withdraw to only allow from unlocked positions
    function withdraw(uint256 assets, address receiver, address owner)
        public virtual override returns (uint256 shares) {
        shares = previewWithdraw(assets);

        // Check if caller is guardian/vault ops
        bool isPrivileged = roleManager.hasRole(roleManager.ROLE_GUARDIAN(), msg.sender) ||
                           roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), msg.sender);

        if (!isPrivileged) {
            uint256 unlockedShares = getUnlockedShares(owner);
            require(shares <= unlockedShares, "Insufficient unlocked shares");
        }

        // Burn from positions (ignore locks if privileged)
        _burnFromPositions(owner, shares, isPrivileged);

        // Execute withdrawal - this handles allowance spending internally
        _withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    /// @notice Override redeem to only allow from unlocked positions
    function redeem(uint256 shares, address receiver, address owner)
        public virtual override returns (uint256 assets) {
        // Check if caller is guardian/vault ops
        bool isPrivileged = roleManager.hasRole(roleManager.ROLE_GUARDIAN(), msg.sender) ||
                           roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), msg.sender);

        if (!isPrivileged) {
            uint256 unlockedShares = getUnlockedShares(owner);
            require(shares <= unlockedShares, "Insufficient unlocked shares");
        }

        // Burn from positions (ignore locks if privileged)
        _burnFromPositions(owner, shares, isPrivileged);

        // Execute redemption - this handles allowance spending internally
        assets = previewRedeem(shares);
        _withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /// @dev Burns shares from user positions (FIFO from unlocked positions)
    function _burnFromPositions(address account, uint256 sharesToBurn, bool ignorelock) private {
        Position[] storage positions = _userPositions[account];
        uint256 remaining = sharesToBurn;

        // First pass: burn from unlocked positions
        for (uint256 i = 0; i < positions.length && remaining > 0; i++) {
            if (positions[i].shares > 0 && (ignorelock || block.timestamp >= positions[i].unlockTime)) {
                uint256 toBurn = positions[i].shares > remaining ? remaining : positions[i].shares;
                positions[i].shares -= toBurn;
                remaining -= toBurn;

                if (positions[i].shares == 0) {
                    emit PositionRedeemed(account, i, toBurn);
                }
            }
        }

        require(remaining == 0, "Insufficient unlocked shares");
    }

    /// @dev Emergency transfer of positions between accounts
    function _emergencyTransferPositions(address from, address to, uint256 value) private {
        // Transfer positions proportionally based on value
        Position[] storage fromPositions = _userPositions[from];
        uint256 totalShares = balanceOf(from);

        if (totalShares == 0 || value == 0) return;

        // If transferring all, move all positions
        if (value == totalShares) {
            for (uint256 i = 0; i < fromPositions.length; i++) {
                if (fromPositions[i].shares > 0) {
                    _userPositions[to].push(fromPositions[i]);
                    fromPositions[i].shares = 0;
                }
            }
        } else {
            // Partial transfer: create proportional positions for recipient
            uint256 transferRatio = (value * 1e18) / totalShares;
            uint256 moved;
            uint256 length = fromPositions.length;
            uint256[] memory recipientIndex = new uint256[](length);

            for (uint256 i = 0; i < length; i++) {
                recipientIndex[i] = type(uint256).max;
                uint256 positionShares = fromPositions[i].shares;
                if (positionShares == 0) continue;

                uint256 transferShares = (positionShares * transferRatio) / 1e18;
                if (transferShares == 0) continue;

                _userPositions[to].push(Position({
                    shares: transferShares,
                    unlockTime: fromPositions[i].unlockTime,
                    depositTime: fromPositions[i].depositTime
                }));

                recipientIndex[i] = _userPositions[to].length - 1;
                fromPositions[i].shares -= transferShares;
                moved += transferShares;
            }

            if (moved < value) {
                uint256 remainder = value - moved;
                for (uint256 i = 0; i < length && remainder > 0; i++) {
                    uint256 available = fromPositions[i].shares;
                    if (available == 0) continue;

                    uint256 add = available > remainder ? remainder : available;
                    fromPositions[i].shares -= add;

                    if (recipientIndex[i] == type(uint256).max) {
                        _userPositions[to].push(Position({
                            shares: add,
                            unlockTime: fromPositions[i].unlockTime,
                            depositTime: fromPositions[i].depositTime
                        }));
                        recipientIndex[i] = _userPositions[to].length - 1;
                    } else {
                        _userPositions[to][recipientIndex[i]].shares += add;
                    }

                    remainder -= add;
                }
            }
        }
    }

    /// @dev Clean up empty positions to save gas
    function _cleanupEmptyPositions(address account) private {
        Position[] storage positions = _userPositions[account];
        uint256 writeIndex = 0;

        for (uint256 readIndex = 0; readIndex < positions.length; readIndex++) {
            if (positions[readIndex].shares > 0) {
                if (writeIndex != readIndex) {
                    positions[writeIndex] = positions[readIndex];
                }
                writeIndex++;
            }
        }

        // Remove empty positions from the end
        while (positions.length > writeIndex) {
            positions.pop();
        }
    }

    function _handleHarvestDistribution(address payoutAsset, uint256 amount) internal override returns (uint256) {
        return PayoutRouter(payable(payoutRouter)).distributeToAllUsers(payoutAsset, amount);
    }

    function _updateUserShares(address account) internal override {
        if (payoutRouter != address(0)) {
            PayoutRouter(payable(payoutRouter)).updateUserShares(account, address(this), balanceOf(account));
        }
    }

    function _handleEmergencyDistribution(address payoutAsset, uint256 amount) internal override {
        PayoutRouter(payable(payoutRouter)).distributeToAllUsers(payoutAsset, amount);
    }

    /// @notice Native ETH deposits are disabled for campaign vaults to ensure lock tracking remains consistent.
    function depositETH(address, uint256)
        public
        payable
        override
        nonReentrant
        returns (uint256)
    {
        revert Errors.OperationNotAllowed();
    }

    function redeemETH(uint256, address, address, uint256)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        revert Errors.OperationNotAllowed();
    }

    function withdrawETH(uint256, address, address, uint256)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        revert Errors.OperationNotAllowed();
    }
}
