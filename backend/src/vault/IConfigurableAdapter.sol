// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Interface for adapters that support vault-specific configuration
interface IConfigurableAdapter {
    function configureForVault(address vault) external;
}