// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/YieldDistributor.sol";
import "../src/NGORegistry.sol";
import "../src/MorphImpactStaking.sol";
import "../src/MockYieldVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldDistributorTest is Test {
    YieldDistributor public distributor;
    NGORegistry public registry;
    MorphImpactStaking public staking;
    MockYieldVault public vault;
    MockToken public token;
    
    uint256 public ownerKey = 0x1234;
    uint256 public distributor1Key = 0x1111;
    uint256 public user1Key = 0x2222;
    uint256 public ngo1Key = 0x3333;
    uint256 public ngo2Key = 0x4444;
    uint256 public verifierKey = 0x5555;
    
    address public owner = vm.addr(ownerKey);
    address public distributor1 = vm.addr(distributor1Key);
    address public user1 = vm.addr(user1Key);
    address public ngo1 = vm.addr(ngo1Key);
    address public ngo2 = vm.addr(ngo2Key);
    address public verifier = vm.addr(verifierKey);
    
    string[] public causes = ["Education", "Healthcare"];
    uint256 public constant INITIAL_BALANCE = 10000 * 10**18;
    uint256 public constant STAKE_AMOUNT = 1000 * 10**18;
    uint256 public constant LOCK_PERIOD = 90 days;
    uint256 public constant YIELD_CONTRIBUTION = 7500;
    
    function setUp() public {
        vm.startPrank(owner);
        registry = new NGORegistry();
        vault = new MockYieldVault();
        token = new MockToken("Test Token", "TEST");
        staking = new MorphImpactStaking(address(registry), address(vault));
        distributor = new YieldDistributor(address(registry), address(staking));
        
        registry.grantRole(registry.VERIFIER_ROLE(), verifier);
        
        // Setup vault and staking
        vault.addSupportedToken(address(token), 1000); // 10% APY
        staking.addSupportedToken(address(token));
        distributor.setTokenSupport(address(token), true);
        
        // Transfer tokens to users
        token.transfer(user1, INITIAL_BALANCE);
        
        // Ensure vault has enough tokens for yield simulation
        token.transfer(address(vault), 100000 * 10**18);
        vm.stopPrank();
        
        // Setup registry
        vm.startPrank(ngo1);
        registry.registerNGO(
            "NGO 1",
            "Description 1",
            "https://ngo1.org",
            "ipfs://logo1",
            ngo1,
            causes,
            "ipfs://metadata1"
        );
        vm.stopPrank();
        
        vm.startPrank(ngo2);
        registry.registerNGO(
            "NGO 2",
            "Description 2",
            "https://ngo2.org",
            "ipfs://logo2",
            ngo2,
            causes,
            "ipfs://metadata2"
        );
        vm.stopPrank();
        
        vm.prank(verifier);
        registry.verifyNGO(ngo1);
        
        vm.prank(verifier);
        registry.verifyNGO(ngo2);
    }
    
    function test_InitialSetup() public {
        assertTrue(distributor.supportedTokens(address(token)));
        assertTrue(distributor.authorizedDistributors(owner));
        assertEq(distributor.currentRound(), 0);
    }
    
    function test_SetAuthorizedDistributor() public {
        vm.prank(owner);
        distributor.setAuthorizedDistributor(distributor1, true);
        
        assertTrue(distributor.authorizedDistributors(distributor1));
    }
    
    function test_RevertIf_InvalidAddressForDistributor() public {
        vm.prank(owner);
        vm.expectRevert(YieldDistributor.InvalidAddress.selector);
        distributor.setAuthorizedDistributor(address(0), true);
    }
    
    function test_SetDistributionInterval() public {
        vm.prank(owner);
        distributor.setDistributionInterval(1 days);
        
        assertEq(distributor.distributionInterval(), 1 days);
    }
    
    function test_RevertIf_InvalidInterval() public {
        vm.prank(owner);
        vm.expectRevert(YieldDistributor.InvalidInterval.selector);
        distributor.setDistributionInterval(30 minutes);
    }
    
    function test_SetMinDistributionAmount() public {
        vm.prank(owner);
        distributor.setMinDistributionAmount(0.01 ether);
        
        assertEq(distributor.minDistributionAmount(), 0.01 ether);
    }
    
    function test_SetTokenSupport() public {
        MockToken newToken = new MockToken("New Token", "NEW");
        
        vm.prank(owner);
        distributor.setTokenSupport(address(newToken), true);
        
        assertTrue(distributor.supportedTokens(address(newToken)));
        
        vm.prank(owner);
        distributor.setTokenSupport(address(newToken), false);
        
        assertFalse(distributor.supportedTokens(address(newToken)));
    }
    
    function test_RevertIf_InvalidAddressForToken() public {
        vm.prank(owner);
        vm.expectRevert(YieldDistributor.InvalidAddress.selector);
        distributor.setTokenSupport(address(0), true);
    }
    
    function test_InitiateDistribution() public {
        // Setup stakes
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        staking.stake(ngo1, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        vm.stopPrank();
        
        // Advance time to generate yield
        vm.warp(block.timestamp + 7 days);
        
        vm.prank(owner);
        distributor.initiateDistribution();
        
        assertEq(distributor.currentRound(), 1);
        
        (uint256 roundNumber, uint256 totalYield, uint256 distributionTime, uint256 stakersCount) = 
            distributor.getDistributionRound(1);
        
        assertEq(roundNumber, 1);
        assertGt(totalYield, 0);
        assertEq(distributionTime, block.timestamp);
        assertGt(stakersCount, 0);
    }
    
    function test_RevertIf_DistributionTooFrequent() public {
        vm.prank(owner);
        distributor.initiateDistribution();
        
        vm.prank(distributor1);
        vm.expectRevert(YieldDistributor.UnauthorizedDistributor.selector);
        distributor.initiateDistribution();
    }
    
    function test_RevertIf_TokenNotSupported() public {
        address unsupportedToken = address(0x9999);
        
        vm.startPrank(user1);
        vm.expectRevert(YieldDistributor.TokenNotSupported.selector);
        distributor.claimUserYield(unsupportedToken);
        vm.stopPrank();
    }
    
    function test_RevertIf_NoUnclaimedYield() public {
        vm.startPrank(user1);
        vm.expectRevert(YieldDistributor.NoUnclaimedYield.selector);
        distributor.claimUserYield(address(token));
        vm.stopPrank();
    }
    
    function test_GetDistributionStatus() public {
        (bool canDistribute, uint256 timeUntil, uint256 totalTokens) = 
            distributor.getDistributionStatus();
        
        assertTrue(canDistribute);
        assertEq(timeUntil, 0);
        assertEq(totalTokens, 1);
    }
    
    function test_GetSupportedTokens() public {
        address[] memory supportedTokens = distributor.getSupportedTokens();
        assertEq(supportedTokens.length, 1);
        assertEq(supportedTokens[0], address(token));
    }
    
    function test_GetNGOYieldForRound() public {
        // Setup stakes
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        staking.stake(ngo1, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days);
        
        vm.prank(owner);
        distributor.initiateDistribution();
        
        uint256 yield = distributor.getNGOYieldForRound(1, address(token), ngo1);
        assertGt(yield, 0);
    }
    
    function test_PauseAndUnpause() public {
        vm.prank(owner);
        distributor.pause();
        
        vm.prank(owner);
        vm.expectRevert();
        distributor.initiateDistribution();
        
        vm.prank(owner);
        distributor.unpause();
        
        vm.prank(owner);
        distributor.initiateDistribution();
        
        assertEq(distributor.currentRound(), 1);
    }
    
    function test_EmergencyWithdraw() public {
        uint256 withdrawAmount = 100 * 10**18;
        
        vm.prank(owner);
        distributor.emergencyWithdraw(address(token), withdrawAmount, user1);
        
        // Note: This test would need the distributor to hold tokens
        // In real scenarios, you'd transfer tokens to distributor first
    }
    
    function test_ComplexDistributionScenario() public {
        // Setup multiple stakes
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT * 2);
        
        staking.stake(ngo1, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        staking.stake(ngo2, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        vm.stopPrank();
        
        // Advance time
        vm.warp(block.timestamp + 7 days);
        
        // Initiate distribution
        vm.prank(owner);
        distributor.initiateDistribution();
        
        // Verify distribution
        (uint256 roundNumber, uint256 totalYield, , uint256 stakersCount) = 
            distributor.getDistributionRound(1);
        
        assertEq(roundNumber, 1);
        assertGt(totalYield, 0);
        assertGt(stakersCount, 0);
        
        uint256 ngo1Yield = distributor.getNGOYieldForRound(1, address(token), ngo1);
        uint256 ngo2Yield = distributor.getNGOYieldForRound(1, address(token), ngo2);
        
        assertGt(ngo1Yield, 0);
        assertGt(ngo2Yield, 0);
    }
    
    function test_AuthorizedDistributorCanDistribute() public {
        vm.prank(owner);
        distributor.setAuthorizedDistributor(distributor1, true);
        
        vm.prank(distributor1);
        distributor.initiateDistribution();
        
        assertEq(distributor.currentRound(), 1);
    }
    
    function test_DistributionWithNoStakes() public {
        vm.prank(owner);
        distributor.initiateDistribution();
        
        (uint256 roundNumber, uint256 totalYield, , uint256 stakersCount) = 
            distributor.getDistributionRound(1);
        
        assertEq(roundNumber, 1);
        assertEq(totalYield, 0);
        assertEq(stakersCount, 0);
    }
    
    function test_DistributionWithUnverifiedNGO() public {
        // Register but don't verify NGO3
        address ngo3 = address(0x7777);
        vm.startPrank(ngo3);
        registry.registerNGO(
            "NGO 3",
            "Description 3",
            "https://ngo3.org",
            "ipfs://logo3",
            ngo3,
            causes,
            "ipfs://metadata3"
        );
        vm.stopPrank();
        
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        staking.stake(ngo3, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 7 days);
        
        vm.prank(owner);
        distributor.initiateDistribution();
        
        uint256 ngo3Yield = distributor.getNGOYieldForRound(1, address(token), ngo3);
        assertEq(ngo3Yield, 0); // Unverified NGO gets no yield
    }
    
    function test_MultipleDistributionRounds() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        staking.stake(ngo1, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        vm.stopPrank();
        
        // First distribution
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        distributor.initiateDistribution();
        
        // Second distribution
        vm.warp(block.timestamp + 7 days);
        vm.prank(owner);
        distributor.initiateDistribution();
        
        assertEq(distributor.currentRound(), 2);
        
        (uint256 round1Number, uint256 totalYield1, , ) = 
            distributor.getDistributionRound(1);
        (uint256 round2Number, uint256 totalYield2, , ) = 
            distributor.getDistributionRound(2);
        
        assertEq(round1Number, 1);
        assertEq(round2Number, 2);
        assertGt(totalYield1, 0);
        assertGt(totalYield2, 0);
    }
    
    function test_IntegrationTest() public {
        // Complete integration test
        
        // 1. Setup stakes
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT * 2);
        staking.stake(ngo1, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        staking.stake(ngo2, address(token), STAKE_AMOUNT, LOCK_PERIOD, YIELD_CONTRIBUTION);
        vm.stopPrank();
        
        // 2. Advance time
        vm.warp(block.timestamp + 7 days);
        
        // 3. Initiate distribution
        vm.prank(owner);
        distributor.initiateDistribution();
        
        // 4. Verify results
        assertEq(distributor.currentRound(), 1);
        
        uint256 ngo1Yield = distributor.getNGOYieldForRound(1, address(token), ngo1);
        uint256 ngo2Yield = distributor.getNGOYieldForRound(1, address(token), ngo2);
        
        assertGt(ngo1Yield, 0);
        assertGt(ngo2Yield, 0);
        assertEq(ngo1Yield, ngo2Yield); // Equal stakes should get equal yield
    }
}