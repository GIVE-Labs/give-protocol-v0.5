// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NGORegistry.sol";

contract NGORegistryTest is Test {
    NGORegistry public registry;
    
    address public owner = address(0x1234);
    address public verifier = address(0x5678);
    address public ngo1 = address(0x1111);
    address public ngo2 = address(0x2222);
    address public user = address(0x3333);
    
    string public constant NGO_NAME = "Test NGO";
    string public constant NGO_DESCRIPTION = "A test NGO for education";
    string public constant NGO_WEBSITE = "https://testngo.org";
    string public constant NGO_LOGO = "ipfs://testlogo";
    string public constant METADATA_HASH = "ipfs://metadata";
    
    string[] public causes = ["Education", "Healthcare", "Environment"];
    
    function setUp() public {
        vm.prank(owner);
        registry = new NGORegistry();
        
        vm.prank(owner);
        registry.grantRole(registry.VERIFIER_ROLE(), verifier);
    }
    
    function test_RegisterNGO() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        NGORegistry.NGO memory ngo = registry.getNGO(ngo1);
        
        assertEq(ngo.name, NGO_NAME);
        assertEq(ngo.description, NGO_DESCRIPTION);
        assertEq(ngo.website, NGO_WEBSITE);
        assertEq(ngo.logoURI, NGO_LOGO);
        assertEq(ngo.walletAddress, ngo1);
        assertFalse(ngo.isVerified);
        assertTrue(ngo.isActive);
        assertEq(ngo.causes.length, 3);
        assertEq(ngo.reputationScore, 70);
        assertEq(ngo.metadataHash, METADATA_HASH);
        assertTrue(registry.hasRegistered(ngo1));
        assertEq(registry.totalNGOs(), 1);
    }
    
    function test_RevertIf_AlreadyRegistered() public {
        vm.startPrank(ngo1);
        
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.expectRevert(NGORegistry.NGOAlreadyRegistered.selector);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.stopPrank();
    }
    
    function test_RevertIf_InvalidAddress() public {
        vm.prank(ngo1);
        vm.expectRevert(NGORegistry.InvalidNGOAddress.selector);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            address(0),
            causes,
            METADATA_HASH
        );
    }
    
    function test_RevertIf_EmptyName() public {
        vm.prank(ngo1);
        vm.expectRevert(NGORegistry.InvalidName.selector);
        registry.registerNGO(
            "",
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
    }
    
    function test_RevertIf_EmptyCauses() public {
        vm.prank(ngo1);
        string[] memory emptyCauses = new string[](0);
        vm.expectRevert(NGORegistry.EmptyCauses.selector);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            emptyCauses,
            METADATA_HASH
        );
    }
    
    function test_VerifyNGO() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(verifier);
        registry.verifyNGO(ngo1);
        
        NGORegistry.NGO memory ngo = registry.getNGO(ngo1);
        assertTrue(ngo.isVerified);
    }
    
    function test_RevertIf_AlreadyVerified() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(verifier);
        registry.verifyNGO(ngo1);
        
        vm.prank(verifier);
        vm.expectRevert(NGORegistry.NGOAlreadyVerified.selector);
        registry.verifyNGO(ngo1);
    }
    
    function test_RevertIf_NotRegisteredForVerification() public {
        vm.prank(verifier);
        vm.expectRevert(NGORegistry.NGONotRegistered.selector);
        registry.verifyNGO(ngo1);
    }
    
    function test_UpdateNGOInfo() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        string memory newName = "Updated NGO";
        string memory newDescription = "Updated description";
        string memory newWebsite = "https://updated.org";
        string memory newLogo = "ipfs://updatedlogo";
        string memory newMetadata = "ipfs://updatedmetadata";
        string[] memory newCauses = ["Updated Cause"];
        
        vm.prank(ngo1);
        registry.updateNGOInfo(
            ngo1,
            newName,
            newDescription,
            newWebsite,
            newLogo,
            newCauses,
            newMetadata
        );
        
        NGORegistry.NGO memory ngo = registry.getNGO(ngo1);
        assertEq(ngo.name, newName);
        assertEq(ngo.description, newDescription);
        assertEq(ngo.website, newWebsite);
        assertEq(ngo.logoURI, newLogo);
        assertEq(ngo.causes.length, 1);
        assertEq(ngo.causes[0], "Updated Cause");
        assertEq(ngo.metadataHash, newMetadata);
    }
    
    function test_RevertIf_UpdateNotAuthorized() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(user);
        vm.expectRevert(NGORegistry.NotAuthorized.selector);
        registry.updateNGOInfo(
            ngo1,
            "Updated",
            "Updated",
            "https://updated.org",
            "ipfs://updated",
            causes,
            METADATA_HASH
        );
    }
    
    function test_FlagCauseDeviation() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(verifier);
        registry.flagCauseDeviation(ngo1, "Deviation reason");
        
        (bool isFlagged, string memory reason, uint256 timestamp, address reporter) = 
            registry.getCauseDeviation(ngo1);
        
        assertTrue(isFlagged);
        assertEq(reason, "Deviation reason");
        assertEq(reporter, verifier);
        assertEq(timestamp, block.timestamp);
    }
    
    function test_UpdateReputationScore() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(verifier);
        registry.updateReputationScore(ngo1, 85);
        
        NGORegistry.NGO memory ngo = registry.getNGO(ngo1);
        assertEq(ngo.reputationScore, 85);
    }
    
    function test_RevertIf_InvalidReputationScore() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(verifier);
        vm.expectRevert(NGORegistry.InvalidReputationScore.selector);
        registry.updateReputationScore(ngo1, 69);
        
        vm.prank(verifier);
        vm.expectRevert(NGORegistry.InvalidReputationScore.selector);
        registry.updateReputationScore(ngo1, 101);
    }
    
    function test_GetAllNGOs() public {
        vm.prank(ngo1);
        registry.registerNGO(
            "NGO 1",
            "Description 1",
            "https://ngo1.org",
            "ipfs://logo1",
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(ngo2);
        registry.registerNGO(
            "NGO 2",
            "Description 2",
            "https://ngo2.org",
            "ipfs://logo2",
            ngo2,
            causes,
            METADATA_HASH
        );
        
        address[] memory allNGOs = registry.getAllNGOs();
        assertEq(allNGOs.length, 2);
        assertEq(allNGOs[0], ngo1);
        assertEq(allNGOs[1], ngo2);
    }
    
    function test_GetNGOsByVerification() public {
        vm.prank(ngo1);
        registry.registerNGO(
            "NGO 1",
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(ngo2);
        registry.registerNGO(
            "NGO 2",
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo2,
            causes,
            METADATA_HASH
        );
        
        vm.prank(verifier);
        registry.verifyNGO(ngo1);
        
        address[] memory verifiedNGOs = registry.getNGOsByVerification(true);
        address[] memory unverifiedNGOs = registry.getNGOsByVerification(false);
        
        assertEq(verifiedNGOs.length, 1);
        assertEq(verifiedNGOs[0], ngo1);
        
        assertEq(unverifiedNGOs.length, 1);
        assertEq(unverifiedNGOs[0], ngo2);
    }
    
    function test_IsVerifiedAndActive() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        assertFalse(registry.isVerifiedAndActive(ngo1));
        
        vm.prank(verifier);
        registry.verifyNGO(ngo1);
        
        assertTrue(registry.isVerifiedAndActive(ngo1));
    }
    
    function test_UpdateStakerCount() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        // Simulate staking contract calling updateStakerCount
        vm.prank(address(0x1234)); // Mock staking contract
        registry.updateStakerCount(ngo1, true);
        
        NGORegistry.NGO memory ngo = registry.getNGO(ngo1);
        assertEq(ngo.activeStakers, 1);
        
        vm.prank(address(0x1234));
        registry.updateStakerCount(ngo1, false);
        
        ngo = registry.getNGO(ngo1);
        assertEq(ngo.activeStakers, 0);
    }
    
    function test_UpdateYieldReceived() public {
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        // Simulate yield distributor calling updateYieldReceived
        vm.prank(address(0x5678)); // Mock yield distributor
        registry.updateYieldReceived(ngo1, 1000);
        
        NGORegistry.NGO memory ngo = registry.getNGO(ngo1);
        assertEq(ngo.totalYieldReceived, 1000);
    }
    
    function test_SetMinReputationScore() public {
        vm.prank(owner);
        registry.setMinReputationScore(75);
        assertEq(registry.minReputationScore(), 75);
    }
    
    function test_SetMaxReputationScore() public {
        vm.prank(owner);
        registry.setMaxReputationScore(95);
        assertEq(registry.maxReputationScore(), 95);
    }
    
    function test_PauseAndUnpause() public {
        vm.prank(owner);
        registry.pause();
        
        vm.prank(ngo1);
        vm.expectRevert("Pausable: paused");
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        vm.prank(owner);
        registry.unpause();
        
        vm.prank(ngo1);
        registry.registerNGO(
            NGO_NAME,
            NGO_DESCRIPTION,
            NGO_WEBSITE,
            NGO_LOGO,
            ngo1,
            causes,
            METADATA_HASH
        );
        
        assertEq(registry.totalNGOs(), 1);
    }
}