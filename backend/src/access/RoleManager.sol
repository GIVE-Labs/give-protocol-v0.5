// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/// @title RoleManager
/// @notice Centralized access control authority for the GIVE Protocol ecosystem.
/// @dev Wraps OpenZeppelin's AccessControlEnumerable to provide shared role IDs and helper queries.
contract RoleManager is AccessControlEnumerable {
    /// @notice Role identifiers used across the protocol.
    bytes32 public constant ROLE_CAMPAIGN_ADMIN = keccak256("ROLE_CAMPAIGN_ADMIN");
    bytes32 public constant ROLE_STRATEGY_ADMIN = keccak256("ROLE_STRATEGY_ADMIN");
    bytes32 public constant ROLE_KEEPER = keccak256("ROLE_KEEPER");
    bytes32 public constant ROLE_CURATOR = keccak256("ROLE_CURATOR");
    bytes32 public constant ROLE_VAULT_OPS = keccak256("ROLE_VAULT_OPS");
    bytes32 public constant ROLE_TREASURY = keccak256("ROLE_TREASURY");
    bytes32 public constant ROLE_GUARDIAN = keccak256("ROLE_GUARDIAN");

    /// @notice Emitted when a batch of roles is granted.
    event RolesGranted(address indexed account, bytes32[] roles);
    /// @notice Emitted when a batch of roles is revoked.
    event RolesRevoked(address indexed account, bytes32[] roles);

    /// @param initialAdmin Address that receives DEFAULT_ADMIN_ROLE on deployment.
    constructor(address initialAdmin) {
        require(initialAdmin != address(0), "RoleManager: zero admin");
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants multiple roles to an account in a single call.
    function grantRoles(address account, bytes32[] calldata roles) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "RoleManager: zero address");
        uint256 length = roles.length;
        for (uint256 i; i < length; ++i) {
            _checkRoleAdmin(roles[i]);
            _grantRole(roles[i], account);
        }
        emit RolesGranted(account, roles);
    }

    /// @notice Revokes multiple roles from an account in a single call.
    function revokeRoles(address account, bytes32[] calldata roles) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "RoleManager: zero address");
        uint256 length = roles.length;
        for (uint256 i; i < length; ++i) {
            _checkRoleAdmin(roles[i]);
            _revokeRole(roles[i], account);
        }
        emit RolesRevoked(account, roles);
    }

    /// @dev Internal helper to ensure msg.sender can administer a role before bulk grant/revoke.
    function _checkRoleAdmin(bytes32 role) internal view {
        require(hasRole(getRoleAdmin(role), _msgSender()), "RoleManager: missing admin role");
    }

    /// @notice Returns true if the account currently holds the campaign admin role.
    function isCampaignAdmin(address account) external view returns (bool) {
        return hasRole(ROLE_CAMPAIGN_ADMIN, account);
    }

    /// @notice Returns true if the account currently holds the strategy admin role.
    function isStrategyAdmin(address account) external view returns (bool) {
        return hasRole(ROLE_STRATEGY_ADMIN, account);
    }

    /// @notice Returns true if the account is an authorised keeper.
    function isKeeper(address account) external view returns (bool) {
        return hasRole(ROLE_KEEPER, account);
    }

    /// @notice Returns true if the account holds the vault-operations role.
    function isVaultOps(address account) external view returns (bool) {
        return hasRole(ROLE_VAULT_OPS, account);
    }

    /// @notice Returns true if the account holds the curator role.
    function isCurator(address account) external view returns (bool) {
        return hasRole(ROLE_CURATOR, account);
    }

    /// @notice Returns true if the account holds the treasury role.
    function isTreasury(address account) external view returns (bool) {
        return hasRole(ROLE_TREASURY, account);
    }

    /// @notice Returns true if the account holds the guardian role.
    function isGuardian(address account) external view returns (bool) {
        return hasRole(ROLE_GUARDIAN, account);
    }
}
