// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Lightweight interface to query the central RoleManager without importing full contract code.
interface IRoleManager {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

/// @title ConfigRegistry
/// @notice Stores discoverable contract addresses and configuration pointers for the GIVE Protocol.
/// @dev Write operations are restricted to addresses holding a designated admin role within the RoleManager.
contract ConfigRegistry {
    /// @dev Reference to the central RoleManager contract.
    IRoleManager public immutable roleManager;
    /// @dev Additional role required for write access (e.g., ROLE_CAMPAIGN_ADMIN).
    bytes32 public immutable adminRole;

    /// @dev Default admin role constant from OpenZeppelin AccessControl (0x00).
    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

    mapping(bytes32 => address) private _addresses;

    event AddressSet(bytes32 indexed key, address indexed value, address indexed caller);
    event AddressRemoved(bytes32 indexed key, address indexed caller);

    error Unauthorized();
    error ZeroAddress();

    /// @param roleManager_ Central RoleManager contract responsible for access checks.
    /// @param adminRole_ Role id within RoleManager allowed to manage registry entries (in addition to default admin).
    constructor(address roleManager_, bytes32 adminRole_) {
        if (roleManager_ == address(0)) revert ZeroAddress();
        roleManager = IRoleManager(roleManager_);
        adminRole = adminRole_;
    }

    modifier onlyAdmin() {
        if (
            !roleManager.hasRole(DEFAULT_ADMIN_ROLE, msg.sender) &&
            !roleManager.hasRole(adminRole, msg.sender)
        ) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Stores or updates an address under the provided key.
    /// @param key Namespaced identifier (e.g., keccak256("CAMPAIGN_REGISTRY")).
    /// @param value Address to associate with the key.
    function setAddress(bytes32 key, address value) external onlyAdmin {
        if (value == address(0)) revert ZeroAddress();
        _addresses[key] = value;
        emit AddressSet(key, value, msg.sender);
    }

    /// @notice Removes an address mapping.
    /// @param key Identifier to clear.
    function removeAddress(bytes32 key) external onlyAdmin {
        delete _addresses[key];
        emit AddressRemoved(key, msg.sender);
    }

    /// @notice Returns the address stored for a given key.
    function getAddress(bytes32 key) external view returns (address) {
        return _addresses[key];
    }
}
