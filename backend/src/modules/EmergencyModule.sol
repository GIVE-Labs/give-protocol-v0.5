// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library EmergencyModule {
    bytes32 public constant MANAGER_ROLE = keccak256("EMERGENCY_MODULE_MANAGER_ROLE");

    enum EmergencyAction {
        Pause,
        Unpause,
        Withdraw
    }

    event EmergencyTriggered(bytes32 indexed vaultId, EmergencyAction action);

    function execute(bytes32 vaultId, EmergencyAction action, bytes calldata) internal {
        emit EmergencyTriggered(vaultId, action);
    }
}
