// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ManualAdapter} from "../src/adapters/ManualAdapter.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {Errors} from "../src/utils/Errors.sol";

contract MockToken is Test {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

contract ManualAdapterTest is Test {
    ManualAdapter internal adapter;
    RoleManager internal roleManager;
    MockToken internal token;

    address internal constant VAULT = address(uint160(uint256(keccak256("vault"))));
    address internal constant STRATEGY_ADMIN = address(uint160(uint256(keccak256("strategyAdmin"))));
    address internal constant GUARDIAN = address(uint160(uint256(keccak256("guardian"))));

    function setUp() public {
        token = new MockToken();
        roleManager = new RoleManager(STRATEGY_ADMIN);

        bytes32 strategyRole = roleManager.ROLE_STRATEGY_ADMIN();
        bytes32 guardianRole = roleManager.ROLE_GUARDIAN();

        vm.prank(STRATEGY_ADMIN);
        roleManager.grantRole(strategyRole, STRATEGY_ADMIN);
        vm.prank(STRATEGY_ADMIN);
        roleManager.grantRole(guardianRole, GUARDIAN);

        adapter = new ManualAdapter(address(roleManager), address(token), VAULT);
    }

    function _seedAdapter(uint256 amount) internal {
        token.mint(VAULT, amount);
        vm.prank(VAULT);
        token.transfer(address(adapter), amount);
        vm.prank(VAULT);
        adapter.invest(amount);
    }

    function testInvestUpdatesAccounting() public {
        uint256 amount = 1_000 ether;
        _seedAdapter(amount);
        assertEq(adapter.totalInvested(), amount);
        assertEq(token.balanceOf(address(adapter)), amount);
    }

    function testManualTransferRequiresStrategyAdmin() public {
        uint256 amount = 1_000 ether;
        _seedAdapter(amount);

        vm.expectRevert(Errors.UnauthorizedManager.selector);
        adapter.manualTransfer(address(0xBEEF), 100 ether);

        vm.prank(STRATEGY_ADMIN);
        adapter.manualTransfer(address(0xBEEF), 600 ether);

        assertEq(token.balanceOf(address(0xBEEF)), 600 ether);
        assertEq(adapter.totalInvested(), amount);
    }

    function testHarvestRecognizesReturnedProfit() public {
        uint256 amount = 1_000 ether;
        _seedAdapter(amount);

        address remote = address(0xBEEF);
        vm.prank(STRATEGY_ADMIN);
        adapter.manualTransfer(remote, 600 ether);

        // remote gains profit and returns funds
        token.mint(remote, 100 ether);
        vm.prank(remote);
        token.transfer(address(adapter), 700 ether);

        uint256 vaultBalanceBefore = token.balanceOf(VAULT);
        vm.prank(VAULT);
        (uint256 profit, uint256 loss) = adapter.harvest();

        assertEq(profit, 100 ether);
        assertEq(loss, 0);
        assertEq(token.balanceOf(VAULT) - vaultBalanceBefore, 100 ether);
        assertEq(adapter.totalInvested(), 1_000 ether);
    }

    function testReportLossAdjustsInvestedAmount() public {
        uint256 amount = 1_000 ether;
        _seedAdapter(amount);

        vm.prank(STRATEGY_ADMIN);
        adapter.reportLoss(200 ether);

        assertEq(adapter.totalInvested(), 800 ether);
        assertEq(adapter.totalReportedLosses(), 200 ether);
    }

    function testEmergencyWithdrawByGuardian() public {
        uint256 amount = 500 ether;
        _seedAdapter(amount);

        vm.prank(GUARDIAN);
        uint256 withdrawn = adapter.emergencyWithdraw();

        assertEq(withdrawn, amount);
        assertEq(token.balanceOf(VAULT), amount);
        assertEq(adapter.totalInvested(), 0);
    }
}
