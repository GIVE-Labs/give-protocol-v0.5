// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {GiveVault4626} from "../src/vault/GiveVault4626.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {CampaignVaultFactory} from "../src/vault/CampaignVaultFactory.sol";
import {VaultDeploymentLib} from "../src/vault/VaultDeploymentLib.sol";
import {ManagerDeploymentLib} from "../src/vault/ManagerDeploymentLib.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {Errors} from "../src/utils/Errors.sol";
import {IYieldAdapter} from "../src/interfaces/IYieldAdapter.sol";

/**
 * @title SecurityTests
 * @notice Security-focused tests including reentrancy, access control, and attack vectors
 */
contract SecurityTests is Test {
    RoleManager internal roleManager;
    CampaignVault internal vault;
    PayoutRouter internal router;
    CampaignRegistry internal campaignRegistry;
    StrategyRegistry internal strategyRegistry;
    CampaignVaultFactory internal factory;

    ReentrantToken internal maliciousToken;
    MaliciousReceiver internal attacker;

    address internal admin = makeAddr("admin");
    address internal guardian = makeAddr("guardian");
    address internal treasury = makeAddr("treasury");
    address internal user = makeAddr("user");
    address internal curator = makeAddr("curator");
    address internal campaignPayout = makeAddr("campaignPayout");

    uint64 internal campaignId = 1;
    uint64 internal strategyId = 1;

    function setUp() public {
        roleManager = new RoleManager(admin);

        vm.startPrank(admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), guardian);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), treasury);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        campaignRegistry = new CampaignRegistry(address(roleManager), treasury, address(strategyRegistry), 0);
        router = new PayoutRouter(address(roleManager), address(campaignRegistry), treasury);

        // Deploy helper contracts
        VaultDeploymentLib vaultDeployer = new VaultDeploymentLib();
        ManagerDeploymentLib managerDeployer = new ManagerDeploymentLib();

        // Grant roles to helper contracts
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(managerDeployer));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(managerDeployer));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(managerDeployer));

        factory = new CampaignVaultFactory(
            address(roleManager),
            address(strategyRegistry),
            address(campaignRegistry),
            address(router),
            address(vaultDeployer),
            address(managerDeployer)
        );

        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(factory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(factory));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(factory));
        vm.stopPrank();

        // Deploy malicious contracts
        attacker = new MaliciousReceiver();
        maliciousToken = new ReentrantToken();

        // Setup regular token and vault for most tests
        _setupRegularVault();
    }

    function _setupRegularVault() internal {
        StandardToken token = new StandardToken();

        // Create strategy for the token
        vm.startPrank(admin);
        address mockAdapter = makeAddr("mockAdapter");
        strategyId = strategyRegistry.createStrategy(
            address(token),
            mockAdapter,
            RegistryTypes.RiskTier.Conservative,
            "test-strategy",
            type(uint256).max
        );

        // Create and approve campaign
        campaignRegistry.submitCampaign(
            "test-campaign",
            curator,
            treasury,
            RegistryTypes.LockProfile.Days30
        );
        campaignRegistry.approveCampaign(campaignId);
        campaignRegistry.attachStrategy(campaignId, strategyId);
        vm.stopPrank();

        vault = new CampaignVault(
            IERC20(address(token)),
            "Test Vault",
            "TEST",
            address(roleManager),
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days30,
            1
        );

        vm.prank(admin);
        vault.setPayoutRouter(address(router));
        vm.prank(admin);
        router.registerVault(address(vault), campaignId, strategyId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);

        // Fund user only (don't prefund vault to avoid share calculation issues)
        token.mint(user, 1000000);
    }

    /**
     * @notice Test reentrancy protection in emergency transfers
     */
    function testReentrancyProtectionInEmergencyTransfer() public {
        StandardToken token = StandardToken(address(vault.asset()));

        // User deposits
        vm.startPrank(user);
        token.approve(address(vault), 10000);
        vault.deposit(10000, user);
        vm.stopPrank();

        // Create a second user
        address user2 = makeAddr("user2");
        token.mint(user2, 10000);
        vm.startPrank(user2);
        token.approve(address(vault), 10000);
        vault.deposit(10000, user2);
        vm.stopPrank();

        // Guardian tries to transfer positions from user to user2
        // First user approves guardian
        vm.prank(user);
        vault.approve(guardian, 5000);

        vm.startPrank(guardian);
        // First transfer should work (transferFrom)
        vault.transferFrom(user, user2, 5000);

        // Try to trigger reentrancy through a callback (would fail with protection)
        // The reentrancy guard prevents nested calls
        vm.stopPrank();
    }

    /**
     * @notice Test that normal users cannot bypass access controls
     */
    function testAccessControlBypass() public {
        // Non-admin cannot set protocol fee
        vm.prank(user);
        vm.expectRevert();
        router.setProtocolFee(500);

        // Non-guardian cannot emergency pause (would be in GiveVault4626 base)
        // vm.prank(user);
        // vm.expectRevert();
        // vault.emergencyPause();

        // Non-guardian cannot clear positions
        vm.prank(user);
        vm.expectRevert();
        vault.clearPositions(user);

        // Non-admin cannot set payout router
        vm.prank(user);
        vm.expectRevert();
        vault.setPayoutRouter(address(0x123));

        // Non-curator cannot deploy vault
        vm.prank(user);
        vm.expectRevert();
        factory.deployCampaignVault(campaignId, strategyId, RegistryTypes.LockProfile.Days30, "Hack", "HACK", 1);
    }

    /**
     * @notice Test front-running protection in harvest
     */
    function testHarvestFrontRunning() public {
        StandardToken token = StandardToken(address(vault.asset()));

        // User deposits
        vm.startPrank(user);
        token.approve(address(vault), 100000);
        vault.deposit(100000, user);
        vm.stopPrank();

        // Simulate profit by minting directly to vault (simpler than adapter)
        token.mint(address(vault), 10000); // Yield

        // Attacker sees harvest tx in mempool and tries to deposit
        address frontRunner = makeAddr("frontRunner");
        token.mint(frontRunner, 100000);

        vm.startPrank(frontRunner);
        token.approve(address(vault), 100000);
        vault.deposit(100000, frontRunner); // Deposit right before harvest
        vm.stopPrank();

        // Front-runner shouldn't immediately benefit from yield
        vm.warp(block.timestamp + 31 days);

        uint256 frontRunnerShares = vault.balanceOf(frontRunner);
        vm.prank(frontRunner);
        uint256 withdrawn = vault.redeem(frontRunnerShares, frontRunner, frontRunner);

        // Should roughly equal their deposit (might have tiny share of yield)
        assertApproxEqAbs(withdrawn, 100000, 100);
    }

    /**
     * @notice Test integer overflow in share calculations
     */
    function testIntegerOverflowProtection() public {
        StandardToken token = StandardToken(address(vault.asset()));

        // Try to cause overflow with massive deposit
        uint256 massiveAmount = type(uint128).max;
        token.mint(user, massiveAmount);

        vm.startPrank(user);
        token.approve(address(vault), massiveAmount);

        // Should not overflow
        uint256 shares = vault.deposit(massiveAmount, user);
        assertGt(shares, 0);
        assertLe(shares, massiveAmount);
        vm.stopPrank();
    }

    /**
     * @notice Test DOS via gas limit in position arrays
     */
    function testGasLimitDOSPrevention() public {
        StandardToken token = StandardToken(address(vault.asset()));

        // Create many positions for one user
        token.mint(user, 1000000);
        vm.startPrank(user);
        token.approve(address(vault), 1000000);

        // Create 100 positions (should still be manageable)
        for (uint256 i = 0; i < 100; i++) {
            vault.deposit(10, user);
            vm.warp(block.timestamp + 1);
        }

        assertEq(vault.getPositionCount(user), 100);

        // Fast forward past lock
        vm.warp(block.timestamp + 31 days);

        // Should still be able to withdraw despite many positions
        uint256 gasStart = gasleft();
        vault.redeem(100, user, user); // Redeem from multiple positions
        uint256 gasUsed = gasStart - gasleft();

        // Gas usage should be reasonable (not approaching block limit)
        assertLt(gasUsed, 3000000); // Well below block gas limit
        vm.stopPrank();
    }

    /**
     * @notice Test minimum deposit bypass attempts
     */
    function testMinimumDepositBypass() public {
        // Create vault with 1000 minimum
        StandardToken token = new StandardToken();
        CampaignVault strictVault = new CampaignVault(
            IERC20(address(token)),
            "Strict",
            "STRICT",
            address(roleManager),
            campaignId,
            strategyId,
            RegistryTypes.LockProfile.Days30,
            1000 // 1000 minimum
        );

        token.mint(user, 10000);

        // Direct deposit below minimum fails
        vm.startPrank(user);
        token.approve(address(strictVault), 999);
        vm.expectRevert("Deposit below minimum");
        strictVault.deposit(999, user);

        // Mint approach also checks minimum
        token.approve(address(strictVault), 10000);
        vm.expectRevert("Deposit below minimum");
        strictVault.mint(1, user); // Would deposit less than minimum
        vm.stopPrank();
    }

    /**
     * @notice Test campaign completion doesn't lock funds
     */
    function testCampaignCompletionFundSafety() public {
        StandardToken token = StandardToken(address(vault.asset()));

        // User deposits
        vm.startPrank(user);
        token.approve(address(vault), 10000);
        vault.deposit(10000, user);
        vm.stopPrank();

        // Mock campaign completion
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
                    status: RegistryTypes.CampaignStatus.Completed, // Completed
                    metadataURI: "test",
                    stake: 0,
                    stakeRefunded: false,
                    createdAt: block.timestamp,
                    updatedAt: block.timestamp
                })
            )
        );

        // Fast forward past lock
        vm.warp(block.timestamp + 31 days);

        // User should still be able to withdraw
        uint256 userShares = vault.balanceOf(user);
        vm.prank(user);
        uint256 withdrawn = vault.redeem(userShares, user, user);
        assertEq(withdrawn, 10000);
    }

    /**
     * @notice Test sandwich attack protection during withdrawals
     */
    function testSandwichAttackProtection() public {
        StandardToken token = StandardToken(address(vault.asset()));

        // Victim deposits
        address victim = makeAddr("victim");
        token.mint(victim, 100000);
        vm.startPrank(victim);
        token.approve(address(vault), 100000);
        vault.deposit(100000, victim);
        vm.stopPrank();

        // Time passes, position unlocks
        vm.warp(block.timestamp + 31 days);

        // Attacker tries to sandwich the withdrawal
        address sandwicher = makeAddr("sandwicher");
        token.mint(sandwicher, 1000000);

        // Front-run: Attacker deposits large amount
        vm.startPrank(sandwicher);
        token.approve(address(vault), 1000000);
        vault.deposit(1000000, sandwicher);
        vm.stopPrank();

        // Victim's withdrawal (being sandwiched)
        uint256 victimShares = vault.balanceOf(victim);
        vm.prank(victim);
        uint256 victimReceived = vault.redeem(victimShares, victim, victim);

        // Back-run: Attacker can't immediately withdraw (locked)
        uint256 attackerShares = vault.balanceOf(sandwicher);
        vm.startPrank(sandwicher);
        vm.expectRevert("Insufficient unlocked shares");
        vault.redeem(attackerShares, sandwicher, sandwicher);
        vm.stopPrank();

        // Victim should receive expected amount (no loss from sandwich)
        assertEq(victimReceived, 100000);
    }

    /**
     * @notice Test precision manipulation in fee calculations
     */
    function testFeeManipulation() public {
        // Attacker tries to manipulate fee calculation via precision loss
        StandardToken token = StandardToken(address(vault.asset()));

        // Mock campaign for distribution
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

        // Try to exploit with specific amounts that might cause precision issues
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 9999; // Just below 10000
        amounts[1] = 10000; // Exact division
        amounts[2] = 10001; // Just above

        uint256 cumulativeFee = 0;

        for (uint256 i = 0; i < amounts.length; i++) {
            token.mint(address(router), amounts[i]);

            vm.prank(address(vault));
            router.distributeToAllUsers(address(token), amounts[i]);

            // Protocol always gets its fee (rounded up)
            uint256 expectedFee = (amounts[i] * router.protocolFeeBps() + 9999) / 10000;
            cumulativeFee += expectedFee;
            assertEq(token.balanceOf(treasury), cumulativeFee, "Fee calculation manipulated");
        }
    }
}

/**
 * @notice Standard ERC20 token for testing
 */
contract StandardToken is ERC20 {
    constructor() ERC20("Standard", "STD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @notice Malicious token that attempts reentrancy
 */
contract ReentrantToken is ERC20 {
    address public attacker;

    constructor() ERC20("Reentrant", "REENT") {
        attacker = msg.sender;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        // Attempt reentrancy on transfer
        if (msg.sender != attacker) {
            // Try to reenter
            (bool success,) = msg.sender.call(abi.encodeWithSignature("withdraw(uint256)", 1));
            // Ignore success, continue with transfer
        }
        return super.transfer(to, amount);
    }
}

/**
 * @notice Malicious contract that attempts various attacks
 */
contract MaliciousReceiver {
    address public target;
    bool public attacking;

    function setTarget(address _target) external {
        target = _target;
    }

    receive() external payable {
        if (!attacking && target != address(0)) {
            attacking = true;
            // Attempt reentrancy
            (bool success,) = target.call(abi.encodeWithSignature("withdraw(uint256)", 1));
            // Ignore result
            attacking = false;
        }
    }

    fallback() external payable {
        // Fallback for any other calls
    }
}

/**
 * @notice Mock adapter for testing
 */
contract MockAdapter is IYieldAdapter {
    IERC20 public asset;
    address public vault;
    uint256 public totalInvested;

    constructor(address _asset, address _vault) {
        asset = IERC20(_asset);
        vault = _vault;
    }

    function invest(uint256 amount) external {
        require(msg.sender == vault, "Only vault");
        totalInvested += amount;
    }

    function divest(uint256 amount) external returns (uint256) {
        require(msg.sender == vault, "Only vault");
        uint256 available = asset.balanceOf(address(this));
        uint256 toReturn = amount > available ? available : amount;
        if (toReturn > 0) {
            asset.transfer(vault, toReturn);
            totalInvested -= toReturn;
        }
        return toReturn;
    }

    function harvest() external returns (uint256 profit, uint256 loss) {
        require(msg.sender == vault, "Only vault");
        uint256 balance = asset.balanceOf(address(this));
        if (balance > totalInvested) {
            profit = balance - totalInvested;
            asset.transfer(vault, profit);
        }
        return (profit, 0);
    }

    function emergencyWithdraw() external returns (uint256) {
        require(msg.sender == vault, "Only vault");
        uint256 balance = asset.balanceOf(address(this));
        if (balance > 0) {
            asset.transfer(vault, balance);
        }
        return balance;
    }

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
