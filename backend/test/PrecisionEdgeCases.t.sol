// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";

/**
 * @title PrecisionEdgeCases
 * @notice Tests for precision loss, rounding errors, and edge cases in calculations
 */
contract PrecisionEdgeCasesTest is Test {
    PayoutRouter internal router;
    CampaignVault internal vault;
    RoleManager internal roleManager;
    CampaignRegistry internal campaignRegistry;
    StrategyRegistry internal strategyRegistry;
    MockToken internal token;

    address internal admin = makeAddr("admin");
    address internal treasury = makeAddr("treasury");
    address internal campaignPayout = makeAddr("campaignPayout");
    address internal curator = makeAddr("curator");

    uint64 internal campaignId = 1;
    uint64 internal strategyId = 1;

    function setUp() public {
        // Deploy infrastructure
        roleManager = new RoleManager(admin);

        vm.startPrank(admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), treasury);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        campaignRegistry = new CampaignRegistry(address(roleManager), treasury, address(strategyRegistry), 0);
        router = new PayoutRouter(address(roleManager), address(campaignRegistry), treasury);

        // Mock token with 6 decimals (like USDC)
        token = new MockToken(6);

        // Create mock adapter and strategy
        address mockAdapter = makeAddr("mockAdapter");
        strategyId = strategyRegistry.createStrategy(
            address(token),
            mockAdapter,
            RegistryTypes.RiskTier.Moderate,
            "test-strategy",
            type(uint256).max
        );

        // Create and approve campaign
        campaignRegistry.submitCampaign(
            "test-campaign",
            curator,
            campaignPayout,
            RegistryTypes.LockProfile.Days30
        );
        campaignRegistry.approveCampaign(campaignId);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        // Create vault
        vault = new CampaignVault(
            IERC20(address(token)),
            "Test Vault",
            "tVAULT",
            address(roleManager),
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days30,
            1 // 1 unit minimum
        );

        vault.setPayoutRouter(address(router));
        router.registerVault(address(vault), campaignId, strategyId);
        router.setAuthorizedCaller(address(vault), true);

        vm.stopPrank();
    }

    /**
     * @notice Test protocol fee rounding always favors protocol
     */
    function testProtocolFeeRoundingFavorsProtocol() public {
        // Test various amounts that would cause rounding
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1; // Minimum amount
        amounts[1] = 99; // Will cause rounding with 10% fee
        amounts[2] = 999; // Larger amount with rounding
        amounts[3] = 10001; // Just over round number
        amounts[4] = 123456789; // Large odd number

        uint256 cumulativeFee = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = amounts[i];

            // Calculate fee with rounding up
            uint256 expectedFee = (amount * router.protocolFeeBps() + 9999) / 10000;
            cumulativeFee += expectedFee;

            // Fund router
            token.mint(address(router), amount);

            // Process distribution
            vm.prank(address(vault));
            router.distributeToAllUsers(address(token), amount);

            // Verify treasury received rounded-up fee (cumulative)
            assertEq(token.balanceOf(treasury), cumulativeFee, "Fee should round up");
        }
    }

    /**
     * @notice Test campaign allocation rounding favors campaign
     */
    function testCampaignAllocationRoundingFavorsCampaign() public {
        // Setup user with shares
        address user = makeAddr("user");
        token.mint(user, 1000000);

        vm.startPrank(user);
        token.approve(address(vault), 1000000);
        vault.deposit(1000000, user);

        // Set 75% campaign allocation
        router.setYieldAllocation(address(vault), 75, user);
        vm.stopPrank();

        // Test various yield amounts
        uint256[] memory yields = new uint256[](4);
        yields[0] = 13; // 75% of 13 = 9.75, should round to 10
        yields[1] = 99; // 75% of 99 = 74.25, should round to 75
        yields[2] = 1000; // 75% of 1000 = 750, no rounding
        yields[3] = 10001; // 75% of 10001 = 7500.75, should round to 7501

        // Mock campaign for payout
        vm.mockCall(
            address(campaignRegistry),
            abi.encodeWithSelector(CampaignRegistry.getCampaign.selector, campaignId),
            abi.encode(
                CampaignRegistry.Campaign({
                    id: campaignId,
                    creator: curator,
                    curator: curator,
                    payout: campaignPayout,
                    defaultLock: RegistryTypes.LockProfile.Days30,
                    status: RegistryTypes.CampaignStatus.Active,
                    metadataURI: "test",
                    stake: 0,
                    stakeRefunded: false,
                    createdAt: block.timestamp,
                    updatedAt: block.timestamp
                })
            )
        );

        for (uint256 i = 0; i < yields.length; i++) {
            uint256 yieldAmount = yields[i];

            // Calculate expected amounts
            uint256 protocolFee = (yieldAmount * router.protocolFeeBps() + 9999) / 10000;
            uint256 distributable = yieldAmount - protocolFee;

            // Campaign gets 75% rounded up
            uint256 expectedCampaign = (distributable * 75 + 99) / 100;
            if (expectedCampaign > distributable) expectedCampaign = distributable;

            // Fund router
            token.mint(address(router), yieldAmount);

            // Get balances before distribution
            uint256 prevCampaignBalance = token.balanceOf(campaignPayout);
            uint256 prevUserBalance = token.balanceOf(user);

            // Distribute
            vm.prank(address(vault));
            router.distributeToAllUsers(address(token), yieldAmount);

            // Calculate increments
            uint256 campaignBalanceIncrement = token.balanceOf(campaignPayout) - prevCampaignBalance;
            assertEq(campaignBalanceIncrement, expectedCampaign, "Campaign should get rounded up amount");

            vm.prank(user);
            uint256 claimed = router.claimPersonalYield(address(vault));
            assertEq(claimed, distributable - expectedCampaign, "User claim should match remainder");
            assertEq(token.balanceOf(user) - prevUserBalance, distributable - expectedCampaign);
        }
    }

    /**
     * @notice Test dust amounts don't cause revert
     */
    function testDustAmountHandling() public {
        // Setup multiple users with tiny shares
        address[] memory users = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            users[i] = makeAddr(string.concat("user", vm.toString(i)));
            token.mint(users[i], 1);

            vm.startPrank(users[i]);
            token.approve(address(vault), 1);
            vault.deposit(1, users[i]);
            router.setYieldAllocation(address(vault), 100, address(0));
            vm.stopPrank();
        }

        // Mock campaign
        vm.mockCall(
            address(campaignRegistry),
            abi.encodeWithSelector(CampaignRegistry.getCampaign.selector, campaignId),
            abi.encode(
                CampaignRegistry.Campaign({
                    id: campaignId,
                    creator: curator,
                    curator: curator,
                    payout: campaignPayout,
                    defaultLock: RegistryTypes.LockProfile.Days30,
                    status: RegistryTypes.CampaignStatus.Active,
                    metadataURI: "test",
                    stake: 0,
                    stakeRefunded: false,
                    createdAt: block.timestamp,
                    updatedAt: block.timestamp
                })
            )
        );

        // Distribute 1 wei of yield - should not revert
        token.mint(address(router), 1);

        vm.prank(address(vault));
        router.distributeToAllUsers(address(token), 1);

        // With 10% protocol fee on 1 wei, protocol gets 1 wei, nothing to distribute
        assertEq(token.balanceOf(treasury), 1);
    }

    /**
     * @notice Test precision with different decimal tokens
     */
    function testDifferentDecimalPrecision() public {
        // Test with 18 decimal token
        MockToken token18 = new MockToken(18);

        CampaignVault vault18 = new CampaignVault(
            IERC20(address(token18)),
            "18 Decimal Vault",
            "v18",
            address(roleManager),
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days30,
            1
        );

        vm.prank(admin);
        vault18.setPayoutRouter(address(router));
        vm.prank(admin);
        router.registerVault(address(vault18), campaignId, strategyId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault18), true);

        // Large deposit with 18 decimals
        address whale = makeAddr("whale");
        uint256 deposit = 1000000 * 10**18; // 1M tokens
        token18.mint(whale, deposit);

        vm.startPrank(whale);
        token18.approve(address(vault18), deposit);
        vault18.deposit(deposit, whale);
        router.setYieldAllocation(address(vault18), 50, whale);
        vm.stopPrank();

        // Mock campaign
        vm.mockCall(
            address(campaignRegistry),
            abi.encodeWithSelector(CampaignRegistry.getCampaign.selector, campaignId),
            abi.encode(
                CampaignRegistry.Campaign({
                    id: campaignId,
                    creator: curator,
                    curator: curator,
                    payout: campaignPayout,
                    defaultLock: RegistryTypes.LockProfile.Days30,
                    status: RegistryTypes.CampaignStatus.Active,
                    metadataURI: "test",
                    stake: 0,
                    stakeRefunded: false,
                    createdAt: block.timestamp,
                    updatedAt: block.timestamp
                })
            )
        );

        // Yield with many decimals
        uint256 yield18 = 123456789012345678901234567890; // Large number
        uint256 routerBefore = token18.balanceOf(address(router));
        token18.mint(address(router), yield18);

        uint256 campaignBefore = token18.balanceOf(campaignPayout);
        uint256 treasuryBefore = token18.balanceOf(treasury);
        uint256 whalePrevBalance = token18.balanceOf(whale);

        vm.prank(address(vault18));
        router.distributeToAllUsers(address(token18), yield18);

        // Verify no overflow and correct distribution
        uint256 protocolFee = (yield18 * router.protocolFeeBps() + 9999) / 10000;
        assertEq(token18.balanceOf(treasury) - treasuryBefore, protocolFee);

        uint256 campaignReceived = token18.balanceOf(campaignPayout) - campaignBefore;
        assertGt(campaignReceived, 0);

        vm.prank(whale);
        uint256 whaleClaim = router.claimPersonalYield(address(vault18));
        assertGt(whaleClaim, 0);
        uint256 whaleReceived = token18.balanceOf(whale) - whalePrevBalance;
        assertEq(whaleReceived, whaleClaim);

        uint256 routerRemainder = token18.balanceOf(address(router));
        uint256 distributed = campaignReceived + whaleReceived + protocolFee + routerRemainder;
        assertEq(routerBefore + yield18, distributed);
    }

    /**
     * @notice Test maximum possible values don't overflow
     */
    function testMaxValueNoOverflow() public {
        // Use token with 18 decimals for maximum precision
        MockToken maxToken = new MockToken(18);

        CampaignVault maxVault = new CampaignVault(
            IERC20(address(maxToken)),
            "Max Vault",
            "MAX",
            address(roleManager),
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days30,
            1
        );

        vm.prank(admin);
        maxVault.setPayoutRouter(address(router));
        vm.prank(admin);
        router.registerVault(address(maxVault), campaignId, strategyId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(maxVault), true);

        // Maximum reasonable amount (just under uint256 max / 10000 to avoid overflow)
        uint256 maxAmount = type(uint256).max / 10001;

        // Mock campaign
        vm.mockCall(
            address(campaignRegistry),
            abi.encodeWithSelector(CampaignRegistry.getCampaign.selector, campaignId),
            abi.encode(
                CampaignRegistry.Campaign({
                    id: campaignId,
                    creator: curator,
                    curator: curator,
                    payout: campaignPayout,
                    defaultLock: RegistryTypes.LockProfile.Days30,
                    status: RegistryTypes.CampaignStatus.Active,
                    metadataURI: "test",
                    stake: 0,
                    stakeRefunded: false,
                    createdAt: block.timestamp,
                    updatedAt: block.timestamp
                })
            )
        );

        // This should not overflow
        maxToken.mint(address(router), maxAmount);

        vm.prank(address(maxVault));
        router.distributeToAllUsers(address(maxToken), maxAmount);

        // Verify distribution happened without overflow
        assertGt(maxToken.balanceOf(treasury), 0, "Treasury should receive fee");
    }

    /**
     * @notice Test share calculation edge cases in vault
     */
    function testShareCalculationEdgeCases() public {
        // First depositor advantage test
        address first = makeAddr("first");
        address second = makeAddr("second");

        // First deposits 1 unit
        token.mint(first, 1);
        vm.startPrank(first);
        token.approve(address(vault), 1);
        uint256 firstShares = vault.deposit(1, first);
        vm.stopPrank();

        // Add significant assets to vault (simulating massive yield)
        token.mint(address(vault), 1000000);

        // Second depositor deposits same amount but gets less shares
        token.mint(second, 1);
        vm.startPrank(second);
        token.approve(address(vault), 1);
        uint256 secondShares = vault.deposit(1, second);
        vm.stopPrank();

        // First depositor got more shares for same deposit amount
        assertGt(firstShares, secondShares, "First depositor should have share advantage");

        // Both should be able to withdraw proportionally
        vm.warp(block.timestamp + 31 days); // Past lock period

        vm.prank(first);
        uint256 firstAssets = vault.redeem(firstShares, first, first);

        vm.prank(second);
        uint256 secondAssets = vault.redeem(secondShares, second, second);

        assertGt(firstAssets, secondAssets, "First depositor extracts more value");
    }
}

contract MockToken is ERC20 {
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) ERC20("Mock", "MOCK") {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
