// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CampaignRegistry} from "../campaign/CampaignRegistry.sol";

/// @notice Compatibility shim: NGORegistry preserves historical name used in docs and diagrams.
contract NGORegistry is CampaignRegistry {
    constructor(address roleManager_, address treasury_, address strategyRegistry_, uint256 minimumStakeWei)
        CampaignRegistry(roleManager_, treasury_, strategyRegistry_, minimumStakeWei)
    {}
}
