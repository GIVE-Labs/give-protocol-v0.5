// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/donation/NGORegistry.sol";
import "../src/adapters/MockYieldAdapter.sol";

contract DonationRouterIntegrationTest is BaseProtocolTest {
    address internal depositorOne;
    address internal depositorTwo;
    address internal ngoPrimary;
    address internal ngoSecondary;
    MockYieldAdapter internal mockAdapter;

    function setUp() public override {
        super.setUp();
        depositorOne = makeAddr("depositorOne");
        depositorTwo = makeAddr("depositorTwo");
        ngoPrimary = makeAddr("ngoPrimary");
        ngoSecondary = makeAddr("ngoSecondary");

        mockAdapter = MockYieldAdapter(address(adapter));

        vm.prank(address(vault));
        asset.approve(address(mockAdapter), type(uint256).max);

        NGORegistry registry = NGORegistry(deployment.registry);
        vm.startPrank(admin);
        registry.addNGO(ngoPrimary, "cid-primary", keccak256("primary"), admin);
        registry.addNGO(ngoSecondary, "cid-secondary", keccak256("secondary"), admin);
        router.setAuthorizedCaller(admin, true);
        vm.stopPrank();
    }

    function testHarvestDistributesYieldAccordingToPreferences() public {
        _deposit(depositorOne, 800 ether);
        _deposit(depositorTwo, 400 ether);

        vm.prank(depositorOne);
        router.setUserPreference(ngoPrimary, 100);
        vm.prank(depositorTwo);
        router.setUserPreference(ngoPrimary, 50);

        uint256 profit = 600 ether;
        asset.mint(admin, profit);
        vm.startPrank(admin);
        asset.approve(address(mockAdapter), profit);
        mockAdapter.addYield(profit);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vault.harvest();

        uint256 expectedProtocol = (400 ether * 250) / 10_000 + (200 ether * 250) / 10_000; // 10 + 5
        uint256 expectedNgo = (400 ether - 10 ether) + ((200 ether - 5 ether) * 50) / 100; // 390 + 97 = 487
        uint256 expectedTreasury = (200 ether - 5 ether) - ((200 ether - 5 ether) * 50) / 100; // 98

        assertEq(asset.balanceOf(protocolTreasury), expectedProtocol, "protocol fees");
        assertEq(asset.balanceOf(feeRecipient), expectedTreasury, "treasury fees");
        assertEq(asset.balanceOf(ngoPrimary), expectedNgo, "ngo balance");
        assertEq(router.totalProtocolFees(address(asset)), expectedProtocol);
        assertEq(router.totalDistributions(), 1);
    }

    function testDistributeToMultipleSplitsRemainderAndRecords() public {
        _deposit(depositorOne, 500 ether);

        asset.mint(address(router), 300 ether);

        address[] memory ngos = new address[](2);
        ngos[0] = ngoPrimary;
        ngos[1] = ngoSecondary;

        vm.startPrank(admin);
        router.setAuthorizedCaller(admin, true);
        (uint256 netDonation, uint256 feeAmount) = router.distributeToMultiple(address(asset), 300 ether, ngos);
        vm.stopPrank();

        assertEq(feeAmount, (300 ether * 250) / 10_000, "fee amount");
        assertEq(netDonation, 300 ether - feeAmount, "net donation");

        uint256 expectedPer = netDonation / ngos.length;
        uint256 remainder = netDonation % ngos.length;

        assertEq(asset.balanceOf(ngoPrimary), expectedPer + remainder, "primary receives remainder");
        assertEq(asset.balanceOf(ngoSecondary), expectedPer, "secondary share");
        assertEq(router.totalDonated(address(asset)), netDonation);
        assertEq(router.totalDistributions(), 2);
    }

    function _deposit(address user, uint256 amount) internal {
        asset.mint(user, amount);
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();
    }
}
