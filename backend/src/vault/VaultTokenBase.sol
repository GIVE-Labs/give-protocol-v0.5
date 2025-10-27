// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../utils/ACLShim.sol";
import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

/// @title VaultTokenBase
/// @notice Shared helpers for vault implementations using the shared storage struct.
abstract contract VaultTokenBase is ACLShim, ReentrancyGuard, Pausable {
    bytes32 internal immutable _vaultId;

    constructor(bytes32 vaultId_) {
        _vaultId = vaultId_;
    }

    function vaultId() public view returns (bytes32) {
        return _vaultId;
    }

    function _vaultConfig() internal view returns (GiveTypes.VaultConfig storage cfg) {
        return StorageLib.vault(_vaultId);
    }
}
