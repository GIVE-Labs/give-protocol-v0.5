// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MorphImpactStaking.sol";
import "../src/NGORegistry.sol";
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

contract MorphImpactStakingTest is Test {
    MorphImpactStaking public staking;
    NGORegistry public registry;
    MockYieldVault public vault;
    MockToken public token;
    
    uint256 public ownerKey = 0x1234;
    uint256 public user1Key = 0x1111;
    uint256 public user2Key = 0x2222;
    uint256 public ngo1Key = 0x3333;
    uint256 public ngo2Key = 0x4444;
    uint256 public verifierKey = 0x5555;
    
    address public owner = vm.addr(ownerKey);
    address public user1 = vm.addr(user1Key);
    address public user2 = vm.addr(user2Key);
    address public ngo1 = vm.addr(ngo1Key);
    address public ngo2 = vm.addr(ngo2Key);
    address public verifier = vm.addr(verifierKey);
    
    string[] public causes = ["Education", "Healthcare"];
    uint256 public constant INITIAL_BALANCE = 10000 * 10**18;
    uint256 public constant STAKE_AMOUNT = 1000 * 10**18;
    uint256 public constant LOCK_PERIOD = 90 days;
    uint256 public constant YIELD_CONTRIBUTION = 7500; // 75%
    
    function setUp() public {
        vm.startPrank(owner);
        registry = new NGORegistry();
        vault = new MockYieldVault();
        token = new MockToken("Test Token", "TEST");
        staking = new MorphImpactStaking(address(registry), address(vault));
        
        registry.grantRole(registry.VERIFIER_ROLE(), verifier);
        
        // Setup vault and staking
        vault.addSupportedToken(address(token), 1000); // 10% APY
        staking.addSupportedToken(address(token));
        
        // Transfer tokens to users
        token.transfer(user1, INITIAL_BALANCE);
        token.transfer(user2, INITIAL_BALANCE);
        
        // Ensure vault has enough tokens for yield simulation
        // Transfer the remaining balance to vault after user transfers
        uint256 vaultAmount = 1000000 * 10**18 - (INITIAL_BALANCE * 2);
        token.transfer(address(vault), vaultAmount);
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
        assertTrue(staking.isSupportedToken(address(token)));
        assertTrue(registry.isVerifiedAndActive(ngo1));
        assertTrue(registry.isVerifiedAndActive(ngo2));
    }
    
    function test_Stake() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        MorphImpactStaking.StakeInfo memory stakeInfo = staking.getUserStake(user1, ngo1, address(token));
        uint256 amount = stakeInfo.amount;
        uint256 lockUntil = stakeInfo.lockUntil;
        uint256 yieldRate = stakeInfo.yieldContributionRate;
        bool isActive = stakeInfo.isActive;
        
        assertEq(amount, STAKE_AMOUNT);
        assertEq(lockUntil, block.timestamp + LOCK_PERIOD);
        assertEq(yieldRate, YIELD_CONTRIBUTION);
        assertTrue(isActive);
        
        assertEq(staking.totalStaked(address(token)), STAKE_AMOUNT);
        assertEq(staking.getTotalStakedForNGO(ngo1, address(token)), STAKE_AMOUNT);
    }
    
    function test_RevertIf_UnsupportedToken() public {
        address unsupportedToken = address(0x9999);
        
        vm.startPrank(user1);
        vm.expectRevert(MorphImpactStaking.UnsupportedToken.selector);
        staking.stake(
            ngo1,
            unsupportedToken,
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
    }
    
    function test_RevertIf_InvalidNGO() public {
        address invalidNGO = address(0x6666);
        
        vm.startPrank(user1);
        vm.expectRevert(MorphImpactStaking.InvalidNGO.selector);
        staking.stake(
            invalidNGO,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
    }
    
    function test_RevertIf_InvalidAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(MorphImpactStaking.InvalidAmount.selector);
        staking.stake(
            ngo1,
            address(token),
            0,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
    }
    
    function test_RevertIf_InvalidLockPeriod() public {
        vm.startPrank(user1);
        vm.expectRevert(MorphImpactStaking.InvalidLockPeriod.selector);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            1 days, // Too short
            YIELD_CONTRIBUTION
        );
        
        vm.expectRevert(MorphImpactStaking.InvalidLockPeriod.selector);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            400 days, // Too long
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
    }
    
    function test_RevertIf_InvalidYieldContribution() public {
        vm.startPrank(user1);
        vm.expectRevert(MorphImpactStaking.InvalidYieldContribution.selector);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            4000 // Too low
        );
        
        vm.expectRevert(MorphImpactStaking.InvalidYieldContribution.selector);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            11000 // Too high
        );
        vm.stopPrank();
    }
    
    function test_AddToExistingStake() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT * 2);
        
        // First stake
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        
        // Second stake to same NGO
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        MorphImpactStaking.StakeInfo memory stakeInfo = staking.getUserStake(user1, ngo1, address(token));
        uint256 amount = stakeInfo.amount;
        assertEq(amount, STAKE_AMOUNT * 2);
    }
    
    function test_StakeMultipleNGOs() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT * 2);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        
        staking.stake(
            ngo2,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        address[] memory stakedNGOs = staking.getUserStakedNGOs(user1, address(token));
        assertEq(stakedNGOs.length, 2);
        assertEq(stakedNGOs[0], ngo1);
        assertEq(stakedNGOs[1], ngo2);
        
        assertEq(staking.totalStaked(address(token)), STAKE_AMOUNT * 2);
        assertEq(staking.getTotalStakedForNGO(ngo1, address(token)), STAKE_AMOUNT);
        assertEq(staking.getTotalStakedForNGO(ngo2, address(token)), STAKE_AMOUNT);
    }
    
    function test_Unstake() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        // Advance past lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);
        
        uint256 initialBalance = token.balanceOf(user1);
        
        vm.prank(user1);
        staking.unstake(ngo1, address(token), STAKE_AMOUNT);
        
        uint256 finalBalance = token.balanceOf(user1);
        assertGt(finalBalance, initialBalance);
        
        MorphImpactStaking.StakeInfo memory stakeInfo = staking.getUserStake(user1, ngo1, address(token));
        assertEq(stakeInfo.amount, 0);
        assertFalse(stakeInfo.isActive);
        assertEq(staking.totalStaked(address(token)), 0);
    }
    
    function test_RevertIf_StillLocked() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        
        vm.expectRevert(MorphImpactStaking.StakeStillLocked.selector);
        staking.unstake(ngo1, address(token), STAKE_AMOUNT);
        vm.stopPrank();
    }
    
    function test_RevertIf_NoActiveStake() public {
        vm.startPrank(user1);
        vm.expectRevert(MorphImpactStaking.NoActiveStake.selector);
        staking.unstake(ngo1, address(token), STAKE_AMOUNT);
        vm.stopPrank();
    }
    
    function test_ClaimYieldWithoutUnstaking() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        // Advance time to generate yield
        vm.warp(block.timestamp + 30 days);
        
        uint256 userBalanceBefore = token.balanceOf(user1);
        uint256 ngoBalanceBefore = token.balanceOf(ngo1);
        
        vm.prank(user1);
        staking.claimYield(ngo1, address(token));
        
        assertGt(token.balanceOf(user1), userBalanceBefore);
        assertGt(token.balanceOf(ngo1), ngoBalanceBefore);
    }
    
    function test_GetPendingYield() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days);
        
        (uint256 pendingYield, uint256 userYield, uint256 ngoYield) = 
            staking.getPendingYield(user1, ngo1, address(token));
        
        assertGt(pendingYield, 0);
        assertEq(userYield + ngoYield, pendingYield);
        assertEq((userYield * 10000) / pendingYield, 10000 - YIELD_CONTRIBUTION);
    }
    
    function test_HasActiveStake() public {
        assertFalse(staking.hasActiveStake(user1, ngo1, address(token)));
        
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        assertTrue(staking.hasActiveStake(user1, ngo1, address(token)));
    }
    
    function test_GetTotalYieldForNGO() public {
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days);
        
        vm.prank(user1);
        staking.claimYield(ngo1, address(token));
        
        uint256 yieldForNGO = staking.getTotalYieldForNGO(ngo1, address(token));
        assertGt(yieldForNGO, 0);
    }
    
    function test_AddAndRemoveSupportedToken() public {
        MockToken newToken = new MockToken("New Token", "NEW");
        
        vm.prank(owner);
        staking.addSupportedToken(address(newToken));
        
        assertTrue(staking.isSupportedToken(address(newToken)));
        
        address[] memory supportedTokens = staking.getSupportedTokens();
        assertEq(supportedTokens.length, 2);
        
        vm.prank(owner);
        staking.removeSupportedToken(address(newToken));
        
        assertFalse(staking.isSupportedToken(address(newToken)));
    }
    
    function test_PauseAndUnpause() public {
        vm.prank(owner);
        staking.pause();
        
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        
        vm.expectRevert();
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        vm.prank(owner);
        staking.unpause();
        
        vm.startPrank(user1);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
    }
    
    function test_ComplexScenario() public {
        // User1 stakes for NGO1
        vm.startPrank(user1);
        token.approve(address(staking), STAKE_AMOUNT);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        // User2 stakes for NGO1
        vm.startPrank(user2);
        token.approve(address(staking), STAKE_AMOUNT);
        staking.stake(
            ngo1,
            address(token),
            STAKE_AMOUNT,
            LOCK_PERIOD,
            YIELD_CONTRIBUTION
        );
        vm.stopPrank();
        
        assertEq(staking.getTotalStakedForNGO(ngo1, address(token)), STAKE_AMOUNT * 2);
        assertEq(staking.totalStaked(address(token)), STAKE_AMOUNT * 2);
        
        // Advance and claim yields
        vm.warp(block.timestamp + 30 days);
        
        vm.prank(user1);
        staking.claimYield(ngo1, address(token));
        
        vm.prank(user2);
        staking.claimYield(ngo1, address(token));
        
        // Advance past lock period
        vm.warp(block.timestamp + LOCK_PERIOD);
        
        // Unstake
        vm.prank(user1);
        staking.unstake(ngo1, address(token), STAKE_AMOUNT);
        
        vm.prank(user2);
        staking.unstake(ngo1, address(token), STAKE_AMOUNT);
        
        assertEq(staking.totalStaked(address(token)), 0);
    }
}