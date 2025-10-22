// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SyntheticProxy
/// @notice Minimal storage container used to anchor synthetic asset storage slots.
contract SyntheticProxy {
    bytes32 public immutable syntheticId;

    constructor(bytes32 id) {
        syntheticId = id;
    }

    receive() external payable {
        revert("NO_RECEIVE");
    }
}
