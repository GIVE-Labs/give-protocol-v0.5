// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IACLManager.sol";

/// @title ACLManager
/// @notice Dynamic role manager with propose/accept admin flow and upgrade gating.
contract ACLManager is Initializable, UUPSUpgradeable, IACLManager {
    struct RoleData {
        address admin;
        address pendingAdmin;
        bool exists;
        address[] members;
        mapping(address => bool) isMember;
        mapping(address => uint256) indexPlusOne; // index + 1 to enable swap & pop
    }

    bytes32 public constant ROLE_SUPER_ADMIN = keccak256("ROLE_SUPER_ADMIN");
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    mapping(bytes32 => RoleData) private _roles;

    modifier onlySuperAdmin() {
        if (!hasRole(ROLE_SUPER_ADMIN, msg.sender)) {
            revert UnauthorizedRole(ROLE_SUPER_ADMIN, msg.sender);
        }
        _;
    }

    modifier onlyRoleAdmin(bytes32 roleId) {
        RoleData storage role = _roles[roleId];
        if (!role.exists) revert RoleDoesNotExist(roleId);
        address admin = role.admin;
        if (msg.sender != admin && !hasRole(ROLE_SUPER_ADMIN, msg.sender)) {
            revert UnauthorizedRole(roleId, msg.sender);
        }
        _;
    }

    error ZeroAddress();
    error RoleAlreadyExists(bytes32 roleId);
    error RoleDoesNotExist(bytes32 roleId);
    error UnauthorizedRole(bytes32 roleId, address account);
    error PendingAdminMissing(bytes32 roleId);
    error PendingAdminMismatch(bytes32 roleId, address expected, address actual);
    error AdminMustBeSuper(bytes32 roleId, address admin);

    /// @notice Initializer
    function initialize(address initialSuperAdmin, address upgrader) external initializer {
        if (initialSuperAdmin == address(0) || upgrader == address(0)) revert ZeroAddress();

        _createRole(ROLE_SUPER_ADMIN, initialSuperAdmin, false);
        _grantRole(ROLE_SUPER_ADMIN, initialSuperAdmin);

        _createRole(ROLE_UPGRADER, initialSuperAdmin, false);
        _grantRole(ROLE_UPGRADER, upgrader);
    }

    /// @notice Creates a new role managed by the ACL.
    function createRole(bytes32 roleId, address admin) external onlySuperAdmin {
        if (admin == address(0)) revert ZeroAddress();
        if (!hasRole(ROLE_SUPER_ADMIN, admin)) {
            revert AdminMustBeSuper(roleId, admin);
        }
        _createRole(roleId, admin, true);
    }

    /// @notice Grants `roleId` to `account`.
    function grantRole(bytes32 roleId, address account) external onlyRoleAdmin(roleId) {
        if (account == address(0)) revert ZeroAddress();
        _grantRole(roleId, account);
    }

    /// @notice Revokes `roleId` from `account`.
    function revokeRole(bytes32 roleId, address account) external onlyRoleAdmin(roleId) {
        if (account == address(0)) revert ZeroAddress();
        _revokeRole(roleId, account);
    }

    /// @notice Returns true if `account` holds `roleId`.
    function hasRole(bytes32 roleId, address account) public view returns (bool) {
        RoleData storage role = _roles[roleId];
        if (!role.exists) return false;
        return role.isMember[account];
    }

    /// @notice Returns the admin account for `roleId`.
    function roleAdmin(bytes32 roleId) public view returns (address) {
        RoleData storage role = _roles[roleId];
        if (!role.exists) return address(0);
        return role.admin;
    }

    /// @notice Initiates an admin transfer by proposing `newAdmin`.
    function proposeRoleAdmin(bytes32 roleId, address newAdmin) external onlyRoleAdmin(roleId) {
        if (newAdmin == address(0)) revert ZeroAddress();
        if (!hasRole(ROLE_SUPER_ADMIN, newAdmin)) {
            revert AdminMustBeSuper(roleId, newAdmin);
        }

        RoleData storage role = _roles[roleId];
        role.pendingAdmin = newAdmin;

        emit RoleAdminProposed(roleId, role.admin, newAdmin);
    }

    /// @notice Accepts a pending admin proposal for `roleId`.
    function acceptRoleAdmin(bytes32 roleId) external {
        RoleData storage role = _roles[roleId];
        if (!role.exists) revert RoleDoesNotExist(roleId);

        address pending = role.pendingAdmin;
        if (pending == address(0)) revert PendingAdminMissing(roleId);
        if (pending != msg.sender) {
            revert PendingAdminMismatch(roleId, pending, msg.sender);
        }
        if (!hasRole(ROLE_SUPER_ADMIN, msg.sender)) {
            revert AdminMustBeSuper(roleId, msg.sender);
        }

        address previousAdmin = role.admin;
        role.admin = msg.sender;
        role.pendingAdmin = address(0);

        emit RoleAdminAccepted(roleId, previousAdmin, msg.sender);
    }

    /// @notice Returns the list of members holding `roleId`.
    function getRoleMembers(bytes32 roleId) external view returns (address[] memory) {
        RoleData storage role = _roles[roleId];
        if (!role.exists) revert RoleDoesNotExist(roleId);
        return role.members;
    }

    /// @dev Internal: creates role storage and emits event.
    function _createRole(bytes32 roleId, address admin, bool checkExists) internal {
        RoleData storage role = _roles[roleId];
        if (role.exists) revert RoleAlreadyExists(roleId);

        if (checkExists && !hasRole(ROLE_SUPER_ADMIN, admin)) {
            revert AdminMustBeSuper(roleId, admin);
        }

        role.admin = admin;
        role.exists = true;

        emit RoleCreated(roleId, admin, msg.sender);
    }

    /// @dev Internal: grants a role.
    function _grantRole(bytes32 roleId, address account) internal {
        RoleData storage role = _roles[roleId];
        if (!role.exists) revert RoleDoesNotExist(roleId);
        if (role.isMember[account]) return;

        role.isMember[account] = true;
        role.members.push(account);
        role.indexPlusOne[account] = role.members.length; // store index + 1

        emit RoleGranted(roleId, account, msg.sender);
    }

    /// @dev Internal: revokes a role.
    function _revokeRole(bytes32 roleId, address account) internal {
        RoleData storage role = _roles[roleId];
        if (!role.exists) revert RoleDoesNotExist(roleId);
        if (!role.isMember[account]) return;

        uint256 index = role.indexPlusOne[account];
        if (index != 0) {
            uint256 lastIndex = role.members.length;
            if (index != lastIndex) {
                address lastMember = role.members[lastIndex - 1];
                role.members[index - 1] = lastMember;
                role.indexPlusOne[lastMember] = index;
            }
            role.members.pop();
            role.indexPlusOne[account] = 0;
        }

        role.isMember[account] = false;

        emit RoleRevoked(roleId, account, msg.sender);
    }

    /// @dev UUPS authorization hook.
    function _authorizeUpgrade(address) internal view override {
        if (!hasRole(ROLE_UPGRADER, msg.sender)) {
            revert UnauthorizedRole(ROLE_UPGRADER, msg.sender);
        }
    }
}
