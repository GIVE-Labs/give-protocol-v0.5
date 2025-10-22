// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

library AdapterModule {
    bytes32 public constant MANAGER_ROLE = keccak256("ADAPTER_MODULE_MANAGER_ROLE");

    struct AdapterConfigInput {
        bytes32 id;
        address proxy;
        address implementation;
        address asset;
        GiveTypes.AdapterKind kind;
        bytes32 vaultId;
    }

    event AdapterConfigured(bytes32 indexed id, address proxy, address implementation, address asset);

    function configure(bytes32 adapterId, AdapterConfigInput memory cfg) internal {
        GiveTypes.AdapterConfig storage info = StorageLib.adapter(adapterId);
        info.id = adapterId;
        info.proxy = cfg.proxy;
        info.implementation = cfg.implementation;
        info.asset = cfg.asset;
        info.kind = cfg.kind;
        info.vaultId = cfg.vaultId;
        info.active = true;

        emit AdapterConfigured(adapterId, cfg.proxy, cfg.implementation, cfg.asset);
    }
}
