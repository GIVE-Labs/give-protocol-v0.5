// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../synthetic/SyntheticLogic.sol";
import "../storage/StorageLib.sol";

library SyntheticModule {
    bytes32 public constant MANAGER_ROLE = keccak256("SYNTHETIC_MODULE_MANAGER_ROLE");

    struct SyntheticConfigInput {
        bytes32 id;
        address proxy;
        address asset;
    }

    event SyntheticConfigured(bytes32 indexed id, address proxy, address asset);

    function configure(bytes32 syntheticId, SyntheticConfigInput memory cfg) internal {
        SyntheticLogic.configure(syntheticId, cfg.proxy, cfg.asset);
        emit SyntheticConfigured(syntheticId, cfg.proxy, cfg.asset);
    }
}
