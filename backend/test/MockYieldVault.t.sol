// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MockYieldVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockYieldVaultTest is Test {
    MockYieldVault public vault;
    MockToken public token;

    uint256 public ownerKey = 0x1234;
    uint256 public user1Key = 0x1111;
    uint256 public user2Key = 0x2222;

    address public owner = vm.addr(ownerKey);
    address public user1 = vm.addr(user1Key);
    address public user2 = vm.addr(user2Key);

    uint256 public constant INITIAL_BALANCE = 10000 * 10 ** 18;
    uint256 public constant APY = 1000; // 10% APY

    function setUp() public {
        vm.startPrank(owner);
        vault = new MockYieldVault();
        token = new MockToken("Test Token", "TEST");
        vault.addSupportedToken(address(token), APY);

        // Transfer tokens to users
        token.transfer(user1, INITIAL_BALANCE);
        token.transfer(user2, INITIAL_BALANCE);

        // Ensure vault has enough tokens for yield simulation
        token.transfer(address(vault), 100000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_AddSupportedToken() public {
        MockToken newToken = new MockToken("New Token", "NEW");

        vm.prank(owner);
        vault.addSupportedToken(address(newToken), 2000);

        assertTrue(vault.isSupportedToken(address(newToken)));
        assertEq(vault.getAPY(address(newToken)), 2000);
    }

    function test_RevertIf_AlreadySupported() public {
        vm.prank(owner);
        vm.expectRevert(MockYieldVault.TokenAlreadySupported.selector);
        vault.addSupportedToken(address(token), APY);
    }

    function test_UpdateAPY() public {
        vm.prank(owner);
        vault.updateAPY(address(token), 1500);

        assertEq(vault.getAPY(address(token)), 1500);
    }

    function test_RevertIf_UnsupportedToken() public {
        address unsupportedToken = address(0x9999);
        vm.prank(owner);
        vm.expectRevert(MockYieldVault.UnsupportedToken.selector);
        vault.updateAPY(unsupportedToken, 1500);
    }

    function test_Deposit() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();

        (uint256 amount, uint256 depositTime, uint256 pendingYield) = vault.getDepositInfo(user1, address(token));

        assertEq(amount, depositAmount);
        assertEq(depositTime, block.timestamp);
        assertEq(pendingYield, 0);
        assertEq(vault.getTotalDeposits(address(token)), depositAmount);
    }

    function test_RevertIf_UnsupportedTokenDeposit() public {
        address unsupportedToken = address(0x9999);

        vm.startPrank(user1);
        vm.expectRevert(MockYieldVault.UnsupportedToken.selector);
        vault.deposit(unsupportedToken, 1000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_RevertIf_ZeroAmountDeposit() public {
        vm.startPrank(user1);
        vm.expectRevert(MockYieldVault.ZeroAmount.selector);
        vault.deposit(address(token), 0);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);

        uint256 withdrawAmount = 500 * 10 ** 18;
        vault.withdraw(address(token), withdrawAmount);
        vm.stopPrank();

        (uint256 amount,,) = vault.getDepositInfo(user1, address(token));
        assertEq(amount, depositAmount - withdrawAmount);
        assertEq(vault.getTotalDeposits(address(token)), depositAmount - withdrawAmount);
    }

    function test_RevertIf_InsufficientBalance() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);

        vm.expectRevert(MockYieldVault.InsufficientBalance.selector);
        vault.withdraw(address(token), depositAmount + 1);
        vm.stopPrank();
    }

    function test_RevertIf_ZeroAmountWithdraw() public {
        vm.startPrank(user1);
        vm.expectRevert(MockYieldVault.ZeroAmount.selector);
        vault.withdraw(address(token), 0);
        vm.stopPrank();
    }

    function test_CalculateYield() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 yield = vault.calculateYield(user1, address(token));
        uint256 expectedYield = (depositAmount * APY) / 10000; // 10% of 1000 = 100

        assertApproxEqAbs(yield, expectedYield, 1);
        vm.stopPrank();
    }

    function test_ClaimYield() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);

        // Advance time by 6 months
        vm.warp(block.timestamp + 180 days);

        uint256 initialBalance = token.balanceOf(user1);
        vault.claimYield(address(token));

        uint256 finalBalance = token.balanceOf(user1);
        uint256 yieldEarned = finalBalance - initialBalance;

        uint256 expectedYield = (depositAmount * APY * 180 days) / (10000 * 365 days);
        assertApproxEqAbs(yieldEarned, expectedYield, 1);

        (uint256 amount,, uint256 pendingYield) = vault.getDepositInfo(user1, address(token));
        assertEq(amount, depositAmount);
        assertEq(pendingYield, 0);
        vm.stopPrank();
    }

    function test_RevertIf_NoYieldToClaim() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);

        // Since we now silently return instead of revert, this test should be updated
        vm.recordLogs();
        vault.claimYield(address(token));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Should have no YieldClaimed events since no yield
        bool hasYieldClaimed = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("YieldClaimed(address,address,uint256)")) {
                hasYieldClaimed = true;
                break;
            }
        }
        assertFalse(hasYieldClaimed);
        vm.stopPrank();
    }

    function test_MultipleDeposits() public {
        uint256 deposit1 = 1000 * 10 ** 18;
        uint256 deposit2 = 2000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), deposit1 + deposit2);

        vault.deposit(address(token), deposit1);

        vm.warp(block.timestamp + 30 days);
        vault.deposit(address(token), deposit2);

        vm.warp(block.timestamp + 30 days);

        uint256 yield = vault.calculateYield(user1, address(token));
        // Calculate yield for combined deposits: 3000 tokens for 30 days after second deposit
        uint256 expectedYield = ((deposit1 + deposit2) * APY * 30 days) / (10000 * 365 days);

        // Allow for 1 wei tolerance due to rounding
        assertApproxEqAbs(yield, expectedYield, 1);
        vm.stopPrank();
    }

    function test_MultipleUsers() public {
        uint256 deposit1 = 1000 * 10 ** 18;
        uint256 deposit2 = 2000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), deposit1);
        vault.deposit(address(token), deposit1);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(vault), deposit2);
        vault.deposit(address(token), deposit2);
        vm.stopPrank();

        assertEq(vault.getTotalDeposits(address(token)), deposit1 + deposit2);

        vm.warp(block.timestamp + 365 days);

        uint256 yield1 = vault.calculateYield(user1, address(token));
        uint256 yield2 = vault.calculateYield(user2, address(token));

        uint256 expectedYield1 = (deposit1 * APY) / 10000;
        uint256 expectedYield2 = (deposit2 * APY) / 10000;

        assertApproxEqAbs(yield1, expectedYield1, 1);
        assertApproxEqAbs(yield2, expectedYield2, 1);
    }

    function test_SimulateYield() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 simulatedYield = 100 * 10 ** 18;

        vm.startPrank(owner);
        token.approve(address(vault), depositAmount);

        // Ensure vault has enough tokens for simulation
        token.transfer(address(vault), simulatedYield);

        vault.simulateYield(address(token), simulatedYield);
        vm.stopPrank();

        assertEq(vault.getTotalYieldGenerated(address(token)), simulatedYield);
    }

    function test_GetSupportedTokens() public {
        address[] memory supportedTokens = vault.getSupportedTokens();
        assertEq(supportedTokens.length, 1);
        assertEq(supportedTokens[0], address(token));

        MockToken newToken = new MockToken("New Token", "NEW");
        vm.prank(owner);
        vault.addSupportedToken(address(newToken), 2000);

        supportedTokens = vault.getSupportedTokens();
        assertEq(supportedTokens.length, 2);
    }

    function test_EmergencyWithdraw() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();

        uint256 emergencyAmount = 100 * 10 ** 18;
        vm.prank(owner);
        vault.emergencyWithdraw(address(token), emergencyAmount, user2);

        assertEq(token.balanceOf(user2), INITIAL_BALANCE + emergencyAmount);
    }

    function test_ComplexScenario() public {
        uint256 deposit1 = 1000 * 10 ** 18;
        uint256 deposit2 = 2000 * 10 ** 18;

        // User1 deposits
        vm.startPrank(user1);
        token.approve(address(vault), deposit1);
        vault.deposit(address(token), deposit1);
        vm.stopPrank();

        // Advance 3 months
        vm.warp(block.timestamp + 90 days);

        // User2 deposits
        vm.startPrank(user2);
        token.approve(address(vault), deposit2);
        vault.deposit(address(token), deposit2);
        vm.stopPrank();

        // Advance another 3 months
        vm.warp(block.timestamp + 90 days);

        // User1 claims yield
        uint256 user1BalanceBefore = token.balanceOf(user1);
        vm.prank(user1);
        vault.claimYield(address(token));
        uint256 user1BalanceAfter = token.balanceOf(user1);

        // User1 withdraws
        vm.prank(user1);
        vault.withdraw(address(token), deposit1);

        // Advance another 3 months
        vm.warp(block.timestamp + 90 days);

        // User2 claims yield and withdraws
        uint256 user2BalanceBefore = token.balanceOf(user2);
        vm.startPrank(user2);
        vault.claimYield(address(token));
        vault.withdraw(address(token), deposit2);
        vm.stopPrank();

        assertEq(vault.getTotalDeposits(address(token)), 0);
    }
}
