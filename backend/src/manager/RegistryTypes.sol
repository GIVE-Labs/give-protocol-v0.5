// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Errors} from "../utils/Errors.sol";

/// @title RegistryTypes
/// @notice Shared enums and helpers used by campaign and strategy registries.
library RegistryTypes {
    /// @notice Risk descriptors that campaign curators can map to their strategies.
    enum RiskTier {
        Conservative,
        Moderate,
        Aggressive,
        Experimental
    }

    /// @notice Lifecycle state for registered strategies.
    enum StrategyStatus {
        Inactive,
        Active,
        FadingOut,
        Deprecated
    }

    /// @notice Lifecycle state for registered campaigns.
    enum CampaignStatus {
        Draft,
        Submitted,
        Active,
        Paused,
        Completed,
        Cancelled,
        Archived
    }

    /// @notice Supported lock-in profiles (in days) that vaults can enforce.
    enum LockProfile {
        Days30,
        Days90,
        Days180,
        Days360,
        Minutes1
    }

    /// @notice Returns the lock duration in seconds for a given profile.
    function lockDuration(LockProfile profile) internal pure returns (uint256) {
        if (profile == LockProfile.Days30) return 30 days;
        if (profile == LockProfile.Days90) return 90 days;
        if (profile == LockProfile.Days180) return 180 days;
        if (profile == LockProfile.Days360) return 360 days;
        if (profile == LockProfile.Minutes1) return 1 minutes;
        revert Errors.LockProfileNotAllowed();
    }
}
