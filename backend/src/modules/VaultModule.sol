// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

library VaultModule {
    bytes32 public constant MANAGER_ROLE = keccak256("VAULT_MODULE_MANAGER_ROLE");

    struct VaultConfigInput {
        bytes32 id;
        address proxy;
        address implementation;
        address asset;
        bytes32 adapterId;
        bytes32 donationModuleId;
        uint16 cashBufferBps;
        uint16 slippageBps;
        uint16 maxLossBps;
    }

    event VaultConfigured(bytes32 indexed id, address proxy, address implementation, address asset);

    function configure(bytes32 vaultId, VaultConfigInput memory cfg) internal {
        GiveTypes.VaultConfig storage info = StorageLib.vault(vaultId);
        info.id = vaultId;
        info.proxy = cfg.proxy;
        info.implementation = cfg.implementation;
        info.asset = cfg.asset;
        info.adapterId = cfg.adapterId;
        info.donationModuleId = cfg.donationModuleId;
        info.cashBufferBps = cfg.cashBufferBps;
        info.slippageBps = cfg.slippageBps;
        info.maxLossBps = cfg.maxLossBps;
        info.active = true;

        emit VaultConfigured(vaultId, cfg.proxy, cfg.implementation, cfg.asset);
    }
}
