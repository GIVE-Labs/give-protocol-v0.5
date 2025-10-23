// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PayoutRouter} from "../payout/PayoutRouter.sol";

/// @notice Compatibility shim: DonationRouter name retained for tutorials and tooling.
contract DonationRouter is PayoutRouter {
    constructor(address roleManager_, address campaignRegistry_, address protocolTreasury_)
        PayoutRouter(roleManager_, campaignRegistry_, protocolTreasury_)
    {}
}
