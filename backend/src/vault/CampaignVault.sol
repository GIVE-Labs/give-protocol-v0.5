// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GiveVault4626} from "./GiveVault4626.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {Errors} from "../utils/Errors.sol";
import {PayoutRouter} from "../payout/PayoutRouter.sol";

/// @title CampaignVault
/// @notice ERC-4626 vault variant that tracks campaign/strategy metadata and enforces lock profiles.
contract CampaignVault is GiveVault4626 {
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

    /// @dev User → timestamp after which withdrawals/transfers are permitted.
    mapping(address => uint256) private _unlockAt;

    /// @notice Emitted when an account lock is updated.
    event LockUpdated(address indexed account, uint256 unlockTimestamp);

    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        address roleManager_,
        uint64 campaignId_,
        uint64 strategyId_,
        RegistryTypes.LockProfile lockProfile_
    )
        GiveVault4626(asset, name, symbol, roleManager_)
    {
        campaignId = campaignId_;
        strategyId = strategyId_;
        lockProfile = lockProfile_;
        factory = msg.sender;
        lockDuration = RegistryTypes.lockDuration(lockProfile_);
    }

    /// @notice Returns the timestamp after which an account can freely withdraw/transfer.
    function lockExpiration(address account) external view returns (uint256) {
        return _unlockAt[account];
    }

    /// @notice Guardian utility to clear a user's lock (e.g., emergency scenarios).
    function clearLock(address account) external onlyRole(roleManager.ROLE_GUARDIAN()) {
        _unlockAt[account] = 0;
        emit LockUpdated(account, 0);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && from != to) {
            _enforceLock(from);
            uint256 fromUnlock = _unlockAt[from];
            if (fromUnlock != 0 && fromUnlock > _unlockAt[to]) {
                _unlockAt[to] = fromUnlock;
                emit LockUpdated(to, fromUnlock);
            }
        } else if (from != address(0) && to == address(0)) {
            _enforceLock(from);
        } else if (from == address(0) && to != address(0)) {
            _refreshLock(to);
        }

        super._update(from, to, value);

        if (from != address(0) && balanceOf(from) == 0 && _unlockAt[from] != 0) {
            _unlockAt[from] = 0;
            emit LockUpdated(from, 0);
        }
    }

    function _enforceLock(address owner) internal view {
        uint256 unlockTime = _unlockAt[owner];
        if (unlockTime == 0) return;
        if (block.timestamp >= unlockTime) return;
        if (roleManager.hasRole(roleManager.ROLE_GUARDIAN(), msg.sender)) return;
        if (roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), msg.sender)) return;
        revert Errors.WithdrawalLocked(unlockTime);
    }

    function _refreshLock(address account) private {
        uint256 unlockTime = block.timestamp + lockDuration;
        if (unlockTime > _unlockAt[account]) {
            _unlockAt[account] = unlockTime;
            emit LockUpdated(account, unlockTime);
        }
    }

    function _handleHarvestDistribution(address payoutAsset, uint256 amount)
        internal
        override
        returns (uint256)
    {
        return PayoutRouter(payable(donationRouter)).distributeToAllUsers(payoutAsset, amount);
    }

    function _updateUserShares(address account) internal override {
        if (donationRouter != address(0)) {
            PayoutRouter(payable(donationRouter)).updateUserShares(account, address(this), balanceOf(account));
        }
    }
}
