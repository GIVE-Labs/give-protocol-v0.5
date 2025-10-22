// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";

library SyntheticModule {
    bytes32 public constant MANAGER_ROLE = keccak256("SYNTHETIC_MODULE_MANAGER_ROLE");

    struct SyntheticConfigInput {
        bytes32 id;
        address proxy;
        bytes32 assetId;
    }

    event SyntheticConfigured(bytes32 indexed id, address proxy, bytes32 assetId);

    function configure(bytes32 syntheticId, SyntheticConfigInput memory cfg) internal {
        bytes32 key = keccak256(abi.encodePacked("synthetic", cfg.id));
        StorageLib.setAddress(keccak256(abi.encodePacked(key, "proxy")), cfg.proxy);
        StorageLib.setBytes32(keccak256(abi.encodePacked(key, "asset")), cfg.assetId);
        emit SyntheticConfigured(syntheticId, cfg.proxy, cfg.assetId);
    }
}
