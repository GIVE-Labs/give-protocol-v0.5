// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {RoleAware} from "../access/RoleAware.sol";
import {Errors} from "../utils/Errors.sol";
import {PayoutRouter} from "./PayoutRouter.sol";

/// @title EpochScheduler
/// @notice Coordinates keeper-triggered epoch rollovers for campaign vaults and rewards their work.
contract EpochScheduler is RoleAware, Pausable, ReentrancyGuard {
    struct EpochConfig {
        uint256 duration;
        uint256 reward;
    }

    struct VaultState {
        bool registered;
        uint256 lastEpoch;
    }

    PayoutRouter public immutable payoutRouter;
    address public rewardToken;

    bytes32 public immutable GUARDIAN_ROLE;
    bytes32 public immutable TREASURY_ROLE;

    EpochConfig public config;
    mapping(address => VaultState) public vaultState;

    event VaultRegistered(address indexed vault);
    event KeepRewardClaimed(address indexed vault, address indexed keeper, uint256 amount, uint256 epochTimestamp);
    event EpochConfigUpdated(uint256 duration, uint256 reward);
    event RewardTokenUpdated(address indexed token);

    constructor(address roleManager_, address payoutRouter_, address rewardToken_, uint256 duration, uint256 reward)
        RoleAware(roleManager_)
    {
        if (payoutRouter_ == address(0)) revert Errors.ZeroAddress();
        payoutRouter = PayoutRouter(payoutRouter_);
        rewardToken = rewardToken_;
        config = EpochConfig({duration: duration, reward: reward});

        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
        TREASURY_ROLE = roleManager.ROLE_TREASURY();
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    function setEpochConfig(uint256 newDuration, uint256 newReward) external onlyRole(TREASURY_ROLE) {
        require(newDuration >= 1 days, "duration too short");
        config = EpochConfig({duration: newDuration, reward: newReward});
        emit EpochConfigUpdated(newDuration, newReward);
    }

    function setRewardToken(address token) external onlyRole(TREASURY_ROLE) {
        rewardToken = token;
        emit RewardTokenUpdated(token);
    }

    function registerVault(address vault) external onlyRole(TREASURY_ROLE) {
        vaultState[vault] = VaultState({registered: true, lastEpoch: block.timestamp});
        emit VaultRegistered(vault);
    }

    function processEpoch(address vault, address asset, uint256 harvestedAmount)
        external
        nonReentrant
        whenNotPaused
    {
        VaultState storage state = vaultState[vault];
        if (!state.registered) revert Errors.UnauthorizedCaller(vault);

        EpochConfig memory cfg = config;
        uint256 nextEpoch = state.lastEpoch + cfg.duration;
        if (block.timestamp < nextEpoch) revert Errors.EpochNotReady(nextEpoch);

        state.lastEpoch = block.timestamp;

        payoutRouter.processScheduledPayout(vault, asset, harvestedAmount);

        if (cfg.reward > 0 && rewardToken != address(0)) {
            (bool ok,) = rewardToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, cfg.reward));
            if (ok) {
                emit KeepRewardClaimed(vault, msg.sender, cfg.reward, block.timestamp);
            }
        }
    }
}
