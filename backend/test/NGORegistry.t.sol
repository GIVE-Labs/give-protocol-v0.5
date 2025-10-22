// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/donation/NGORegistry.sol";
import "../src/utils/Errors.sol";

contract NGORegistryTest is BaseProtocolTest {
    NGORegistry internal registry;
    address internal ngo;
    address internal newNgo;

    function setUp() public override {
        super.setUp();
        registry = NGORegistry(deployment.registry);
        ngo = makeAddr("ngo");
        newNgo = makeAddr("ngo-new");

        vm.startPrank(admin);
        acl.createRole(registry.DEFAULT_ADMIN_ROLE(), admin);
        acl.grantRole(registry.DEFAULT_ADMIN_ROLE(), admin);
        vm.stopPrank();
    }

    function testAddUpdateRemoveNGOFlow() public {
        vm.startPrank(admin);
        registry.addNGO(ngo, "cid-initial", keccak256("kyc"), admin);
        registry.updateNGO(ngo, "cid-updated", bytes32(0));
        registry.proposeCurrentNGO(ngo);
        vm.stopPrank();

        vm.warp(block.timestamp + registry.TIMELOCK_DELAY() + 1 seconds);
        registry.executeCurrentNGOChange();

        (string memory metadataCid, bytes32 kycHash,, uint256 createdAt, uint256 updatedAt, uint256 version,, bool isActive) =
            registry.ngoInfo(ngo);
        assertEq(metadataCid, "cid-updated");
        assertEq(kycHash, keccak256("kyc"));
        assertGt(createdAt, 0);
        assertGt(updatedAt, 0);
        assertEq(version, 2);
        assertTrue(isActive);

        vm.startPrank(admin);
        acl.grantRole(registry.DONATION_RECORDER_ROLE(), admin);
        registry.recordDonation(ngo, 100 ether);
        vm.stopPrank();
        assertEq(registry.currentNGO(), ngo);

        vm.prank(admin);
        registry.removeNGO(ngo);
        assertFalse(registry.isApproved(ngo));
    }

    function testTimelockPreventsPrematureExecution() public {
        vm.startPrank(admin);
        registry.addNGO(ngo, "cid", keccak256("kyc"), admin);
        registry.addNGO(newNgo, "cid-new", keccak256("kyc-new"), admin);
        registry.proposeCurrentNGO(newNgo);
        vm.expectRevert(Errors.TimelockNotReady.selector);
        registry.executeCurrentNGOChange();
        vm.stopPrank();

        vm.warp(block.timestamp + registry.TIMELOCK_DELAY() + 1 seconds);
        registry.executeCurrentNGOChange();
        assertEq(registry.currentNGO(), newNgo);
    }
}
