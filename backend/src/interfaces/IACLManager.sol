// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IACLManager {
    event RoleCreated(bytes32 indexed roleId, address indexed admin, address indexed sender);
    event RoleGranted(bytes32 indexed roleId, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed roleId, address indexed account, address indexed sender);
    event RoleAdminProposed(bytes32 indexed roleId, address indexed currentAdmin, address indexed proposedAdmin);
    event RoleAdminAccepted(bytes32 indexed roleId, address indexed previousAdmin, address indexed newAdmin);

    function initialize(address initialSuperAdmin, address upgrader) external;

    function createRole(bytes32 roleId, address admin) external;

    function grantRole(bytes32 roleId, address account) external;

    function revokeRole(bytes32 roleId, address account) external;

    function hasRole(bytes32 roleId, address account) external view returns (bool);

    function roleAdmin(bytes32 roleId) external view returns (address);

    function proposeRoleAdmin(bytes32 roleId, address newAdmin) external;

    function acceptRoleAdmin(bytes32 roleId) external;

    function getRoleMembers(bytes32 roleId) external view returns (address[] memory);
}
