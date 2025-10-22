// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/governance/ACLManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

interface IUUPS {
    function upgradeTo(address newImplementation) external;
}

contract ACLManagerTest is Test {
    ACLManager internal acl;
    address internal superAdmin;
    address internal upgrader;
    address internal alice;
    address internal bob;
    bytes32 internal constant ROLE_SUPER_ADMIN = keccak256("ROLE_SUPER_ADMIN");
    bytes32 internal constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");
    bytes32 internal constant ROLE_TEST = keccak256("ROLE_TEST");

    function setUp() public {
        superAdmin = makeAddr("superAdmin");
        upgrader = makeAddr("upgrader");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        ACLManager implementation = new ACLManager();
        bytes memory initData = abi.encodeWithSelector(ACLManager.initialize.selector, superAdmin, upgrader);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        acl = ACLManager(address(proxy));

        vm.prank(superAdmin);
        acl.createRole(ROLE_TEST, superAdmin);
    }

    function testGrantAndRevokeRole() public {
        vm.prank(superAdmin);
        acl.grantRole(ROLE_TEST, alice);
        assertTrue(acl.hasRole(ROLE_TEST, alice));

        address[] memory members = acl.getRoleMembers(ROLE_TEST);
        assertEq(members.length, 1);
        assertEq(members[0], alice);

        vm.prank(superAdmin);
        acl.revokeRole(ROLE_TEST, alice);
        assertFalse(acl.hasRole(ROLE_TEST, alice));
        members = acl.getRoleMembers(ROLE_TEST);
        assertEq(members.length, 0);
    }

    function testAdminProposalFlow() public {
        vm.prank(superAdmin);
        vm.expectRevert();
        acl.proposeRoleAdmin(ROLE_TEST, alice);

        vm.prank(superAdmin);
        acl.grantRole(ROLE_SUPER_ADMIN, alice);
        assertTrue(acl.hasRole(ROLE_SUPER_ADMIN, alice));

        vm.prank(superAdmin);
        acl.proposeRoleAdmin(ROLE_TEST, alice);

        vm.prank(alice);
        acl.acceptRoleAdmin(ROLE_TEST);
        assertEq(acl.roleAdmin(ROLE_TEST), alice);
    }

    function testOnlyAdminCanGrant() public {
        vm.prank(superAdmin);
        acl.grantRole(ROLE_TEST, alice);

        vm.startPrank(alice);
        vm.expectRevert();
        acl.grantRole(ROLE_TEST, bob);
        vm.stopPrank();

        vm.prank(superAdmin);
        acl.grantRole(ROLE_SUPER_ADMIN, alice);

        vm.prank(alice);
        acl.grantRole(ROLE_TEST, bob);
        assertTrue(acl.hasRole(ROLE_TEST, bob));
    }

    function testAuthorizeUpgrade() public {
        ACLManagerMock newImplementation = new ACLManagerMock();

        vm.prank(alice);
        vm.expectRevert();
        IUUPS(address(acl)).upgradeTo(address(newImplementation));
    }
}

contract ACLManagerMock is ACLManager {}
