// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";
import "../vault/GiveVault4626.sol";

library EmergencyModule {
    bytes32 public constant MANAGER_ROLE = keccak256("EMERGENCY_MODULE_MANAGER_ROLE");

    enum EmergencyAction {
        Pause,
        Unpause,
        Withdraw
    }

    struct EmergencyWithdrawParams {
        bool clearAdapter;
    }

    event EmergencyStateChanged(bytes32 indexed vaultId, bool active, address indexed caller);
    event EmergencyWithdrawal(bytes32 indexed vaultId, address indexed adapter, uint256 amount, bool adapterCleared);

    error EmergencyAlreadyActive(bytes32 vaultId);
    error EmergencyNotActive(bytes32 vaultId);
    error NoActiveAdapter(bytes32 vaultId);

    function execute(bytes32 vaultId, EmergencyAction action, bytes calldata data) internal {
        GiveTypes.VaultConfig storage cfg = StorageLib.ensureVaultActive(vaultId);
        address vaultProxy = cfg.proxy;

        if (action == EmergencyAction.Pause) {
            _pauseVault(cfg, vaultId, vaultProxy);
        } else if (action == EmergencyAction.Unpause) {
            _resumeVault(cfg, vaultId, vaultProxy);
        } else if (action == EmergencyAction.Withdraw) {
            _emergencyWithdraw(cfg, vaultId, vaultProxy, data);
        }
    }

    function _pauseVault(GiveTypes.VaultConfig storage cfg, bytes32 vaultId, address vaultProxy) private {
        if (cfg.emergencyShutdown) revert EmergencyAlreadyActive(vaultId);

        GiveVault4626(payable(vaultProxy)).emergencyPause();
        cfg.emergencyShutdown = true;
        cfg.emergencyActivatedAt = uint64(block.timestamp);
        emit EmergencyStateChanged(vaultId, true, msg.sender);
    }

    function _resumeVault(GiveTypes.VaultConfig storage cfg, bytes32 vaultId, address vaultProxy) private {
        if (!cfg.emergencyShutdown) revert EmergencyNotActive(vaultId);

        GiveVault4626(payable(vaultProxy)).resumeFromEmergency();
        cfg.emergencyShutdown = false;
        cfg.emergencyActivatedAt = 0;

        emit EmergencyStateChanged(vaultId, false, msg.sender);
    }

    function _emergencyWithdraw(
        GiveTypes.VaultConfig storage cfg,
        bytes32 vaultId,
        address vaultProxy,
        bytes calldata data
    ) private {
        if (!cfg.emergencyShutdown) revert EmergencyNotActive(vaultId);
        address adapter = address(GiveVault4626(payable(vaultProxy)).activeAdapter());
        if (adapter == address(0)) revert NoActiveAdapter(vaultId);

        EmergencyWithdrawParams memory params;
        if (data.length > 0) {
            params = abi.decode(data, (EmergencyWithdrawParams));
        }

        uint256 withdrawn = GiveVault4626(payable(vaultProxy)).emergencyWithdrawFromAdapter();
        if (params.clearAdapter) {
            GiveVault4626(payable(vaultProxy)).forceClearAdapter();
            cfg.activeAdapter = address(0);
            cfg.adapterId = bytes32(0);
        }

        emit EmergencyWithdrawal(vaultId, adapter, withdrawn, params.clearAdapter);
    }
}
