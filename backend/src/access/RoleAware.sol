// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRoleManagerCore {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function ROLE_CAMPAIGN_ADMIN() external view returns (bytes32);
    function ROLE_STRATEGY_ADMIN() external view returns (bytes32);
    function ROLE_KEEPER() external view returns (bytes32);
    function ROLE_CURATOR() external view returns (bytes32);
    function ROLE_VAULT_OPS() external view returns (bytes32);
    function ROLE_TREASURY() external view returns (bytes32);
    function ROLE_GUARDIAN() external view returns (bytes32);
}

/// @title RoleAware
/// @notice Utility base contract for modules that rely on the central RoleManager.
abstract contract RoleAware {
    /// @dev OpenZeppelin-style default admin role identifier.
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    /// @notice Reference to the RoleManager contract.
    IRoleManagerCore public immutable roleManager;

    error Unauthorized(address account, bytes32 role);
    error ZeroAddressRoleManager();

    constructor(address roleManager_) {
        if (roleManager_ == address(0)) revert ZeroAddressRoleManager();
        roleManager = IRoleManagerCore(roleManager_);
    }

    /// @dev Ensures the caller holds the required role in the RoleManager.
    modifier onlyRole(bytes32 role) {
        if (!roleManager.hasRole(role, msg.sender)) {
            revert Unauthorized(msg.sender, role);
        }
        _;
    }
}
