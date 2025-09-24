// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {RoleManager} from "../../src/access/RoleManager.sol";
import {ConfigRegistry, IRoleManager} from "../../src/access/ConfigRegistry.sol";

contract RoleManagerTest is Test {
    bytes4 internal constant ACCESS_CONTROL_UNAUTHORIZED =
        bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));

    RoleManager internal roleManager;
    address internal admin = address(this);
    address internal keeper = address(0xBEEF);
    address internal curator = address(0xCAFE);

    function setUp() external {
        roleManager = new RoleManager(admin);
    }

    function testGrantAndRevokeRoles() external {
        bytes32[] memory roles = new bytes32[](2);
        roles[0] = roleManager.ROLE_KEEPER();
        roles[1] = roleManager.ROLE_CURATOR();

        roleManager.grantRoles(keeper, roles);

        assertTrue(roleManager.hasRole(roleManager.ROLE_KEEPER(), keeper));
        assertTrue(roleManager.hasRole(roleManager.ROLE_CURATOR(), keeper));
        assertTrue(roleManager.isKeeper(keeper));
        assertTrue(roleManager.isCurator(keeper));

        roleManager.revokeRoles(keeper, roles);

        assertFalse(roleManager.hasRole(roleManager.ROLE_KEEPER(), keeper));
        assertFalse(roleManager.hasRole(roleManager.ROLE_CURATOR(), keeper));
    }

    function testNonAdminCannotGrant() external {
        bytes32[] memory roles = new bytes32[](1);
        roles[0] = roleManager.ROLE_KEEPER();
        vm.startPrank(address(0xABCD));
        vm.expectRevert(abi.encodeWithSelector(ACCESS_CONTROL_UNAUTHORIZED, address(0xABCD), bytes32(0)));
        roleManager.grantRoles(keeper, roles);
        vm.stopPrank();
    }
}

contract ConfigRegistryTest is Test {
    RoleManager internal roleManager;
    ConfigRegistry internal registry;
    address internal admin = address(this);
    address internal other = address(0x1234);

    bytes32 internal constant KEY = keccak256("TEST_CONFIG_KEY");

    function setUp() external {
        roleManager = new RoleManager(admin);
        registry = new ConfigRegistry(address(roleManager), roleManager.ROLE_CAMPAIGN_ADMIN());
    }

    function testSetAndRemoveAddress() external {
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);

        registry.setAddress(KEY, address(0xBEEF));
        assertEq(registry.getAddress(KEY), address(0xBEEF));

        registry.removeAddress(KEY);
        assertEq(registry.getAddress(KEY), address(0));
    }

    function testUnauthorizedSetReverts() external {
        vm.prank(other);
        vm.expectRevert(ConfigRegistry.Unauthorized.selector);
        registry.setAddress(KEY, address(1));
    }

    function testZeroAddressRejected() external {
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        vm.expectRevert(ConfigRegistry.ZeroAddress.selector);
        registry.setAddress(KEY, address(0));
    }
}
