// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/donation/DonationRouter.sol";
import "../src/donation/NGORegistry.sol";
import "../src/vault/GiveVault4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/access/RoleManager.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract UserPreferencesTest is Test {
    DonationRouter router;
    NGORegistry registry;
    MockERC20 usdc;
    RoleManager roleManager;

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address ngo1 = makeAddr("ngo1");
    address ngo2 = makeAddr("ngo2");
    address feeRecipient = makeAddr("feeRecipient");
    address protocolTreasury = makeAddr("protocolTreasury");
    address caller = makeAddr("caller");

    function setUp() public {
        usdc = new MockERC20();

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        require(roleManager.hasRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin), "admin lacks campaign role");

        registry = new NGORegistry(address(roleManager));
        router = new DonationRouter(
            address(roleManager),
            address(registry),
            feeRecipient,
            protocolTreasury,
            250
        ); // 2.5% fee
        roleManager.grantRole(roleManager.ROLE_DONATION_RECORDER(), address(router));

        vm.startPrank(admin);

        // Setup NGOs
        registry.addNGO(ngo1, "NGO1", bytes32("kyc1"), admin);
        registry.addNGO(ngo2, "NGO2", bytes32("kyc2"), admin);

        // Authorize caller
        router.setAuthorizedCaller(caller, true);
        vm.stopPrank();

        // Mint tokens for testing
        usdc.mint(address(router), 10_000e6);
    }

    function testUserPreferenceWorkflow() public {
        // Test 1: Set user preferences
        vm.prank(user1);
        router.setUserPreference(ngo1, 75); // 75% to NGO, 25% to treasury

        vm.prank(user2);
        router.setUserPreference(ngo2, 100); // 100% to NGO

        // Test 2: Update user shares (simulating vault deposits)
        vm.startPrank(caller);
        router.updateUserShares(user1, address(usdc), 1000e6); // user1 has 1000 shares
        router.updateUserShares(user2, address(usdc), 1000e6); // user2 has 1000 shares
        vm.stopPrank();

        // Test 3: Distribute yield using new system
        uint256 totalYield = 1000e6; // 1000 USDC yield

        uint256 ngo1Before = usdc.balanceOf(ngo1);
        uint256 ngo2Before = usdc.balanceOf(ngo2);
        uint256 treasuryBefore = usdc.balanceOf(feeRecipient);
        uint256 protocolBefore = usdc.balanceOf(protocolTreasury);

        vm.prank(caller);
        uint256 distributed = router.distributeToAllUsers(address(usdc), totalYield);

        // Verify distributions
        assertEq(distributed, totalYield, "Total distributed should equal input");

        // User1: 500 USDC (50% of total yield), 75% to NGO1, 25% to treasury
        // User2: 500 USDC (50% of total yield), 100% to NGO2
        // Protocol fee: 2.5% of each user's yield

        uint256 user1Yield = 500e6;
        uint256 user2Yield = 500e6;

        uint256 user1ProtocolFee = (user1Yield * 250) / 10_000; // 2.5%
        uint256 user2ProtocolFee = (user2Yield * 250) / 10_000; // 2.5%

        uint256 user1NetYield = user1Yield - user1ProtocolFee;
        uint256 user2NetYield = user2Yield - user2ProtocolFee;

        uint256 user1ToNGO = (user1NetYield * 75) / 100;
        uint256 user1ToTreasury = user1NetYield - user1ToNGO;
        uint256 user2ToNGO = user2NetYield; // 100%

        assertEq(usdc.balanceOf(ngo1) - ngo1Before, user1ToNGO, "NGO1 should receive user1's allocation");
        assertEq(usdc.balanceOf(ngo2) - ngo2Before, user2ToNGO, "NGO2 should receive user2's allocation");
        assertEq(
            usdc.balanceOf(feeRecipient) - treasuryBefore, user1ToTreasury, "Treasury should receive user1's remainder"
        );
        assertEq(
            usdc.balanceOf(protocolTreasury) - protocolBefore,
            user1ProtocolFee + user2ProtocolFee,
            "Protocol should receive fees"
        );
    }

    function testFallbackToLegacyDistribution() public {
        // Test distribution when no users have shares (should use legacy system)
        uint256 totalYield = 1000e6;

        uint256 ngoBefore = usdc.balanceOf(ngo1); // ngo1 is the current NGO
        uint256 feeBefore = usdc.balanceOf(feeRecipient);

        vm.prank(caller);
        uint256 distributed = router.distributeToAllUsers(address(usdc), totalYield);

        assertEq(distributed, totalYield, "Total distributed should equal input");

        uint256 expectedFee = (totalYield * 250) / 10_000; // 2.5%
        uint256 expectedDonation = totalYield - expectedFee;

        assertEq(usdc.balanceOf(ngo1) - ngoBefore, expectedDonation, "NGO should receive donation minus fee");
        assertEq(usdc.balanceOf(feeRecipient) - feeBefore, expectedFee, "Fee recipient should receive fee");
    }

    function testGetUserPreference() public {
        vm.prank(user1);
        router.setUserPreference(ngo1, 50);

        DonationRouter.UserPreference memory preference = router.getUserPreference(user1);
        assertEq(preference.selectedNGO, ngo1, "Should return correct NGO");
        assertEq(preference.allocationPercentage, 50, "Should return correct allocation");
    }

    function testCalculateUserDistribution() public {
        vm.prank(user1);
        router.setUserPreference(ngo1, 75);

        uint256 userYield = 1000e6;
        (uint256 ngoAmount, uint256 treasuryAmount, uint256 protocolAmount) =
            router.calculateUserDistribution(user1, userYield);

        uint256 expectedProtocolFee = (userYield * 250) / 10_000; // 2.5%
        uint256 netYield = userYield - expectedProtocolFee;
        uint256 expectedNGOAmount = (netYield * 75) / 100;
        uint256 expectedTreasuryAmount = netYield - expectedNGOAmount;

        assertEq(protocolAmount, expectedProtocolFee, "Protocol fee should be 2.5%");
        assertEq(ngoAmount, expectedNGOAmount, "NGO amount should be 75% of net yield");
        assertEq(treasuryAmount, expectedTreasuryAmount, "Treasury amount should be remainder");
    }
}
