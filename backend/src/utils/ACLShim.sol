// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IACLManager.sol";

/// @title ACLShim
/// @notice Backwards-compatible AccessControl extension that can defer role checks to an external ACL manager.
abstract contract ACLShim is AccessControl {
    IACLManager public aclManager;

    event ACLManagerUpdated(address indexed previousManager, address indexed newManager);

    /// @notice Sets the ACL manager that this contract defers to.
    /// @dev Only callable by the contract's default admin.
    function setACLManager(address manager) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _setACLManager(manager);
    }

    /// @dev Internal setter to support constructor wiring in future upgrades.
    function _setACLManager(address manager) internal {
        address previous = address(aclManager);
        aclManager = IACLManager(manager);
        emit ACLManagerUpdated(previous, manager);
    }

    /// @inheritdoc AccessControl
    function _checkRole(bytes32 role, address account) internal view override {
        if (address(aclManager) != address(0) && aclManager.hasRole(role, account)) {
            return;
        }
        super._checkRole(role, account);
    }
}
