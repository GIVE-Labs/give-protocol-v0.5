// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {RoleManager} from "../src/access/RoleManager.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {CampaignVaultFactory} from "../src/vault/CampaignVaultFactory.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {GiveVault4626} from "../src/vault/GiveVault4626.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";
import {ManualAdapter} from "../src/adapters/ManualAdapter.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";

/**
 * @dev Comprehensive deployment script for Scroll.
 *      Fill in all placeholder addresses with the actual deployment values before running.
 */
contract DeployScroll is Script {
    address internal constant SCROLL_MULTISIG = address(0); // TODO: set protocol admin / multisig

    // === External addresses on Scroll ===
    address internal constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4; // TODO: Scroll USDC token address
    address internal constant WETH = 0x5300000000000000000000000000000000000004; // TODO: Scroll WETH token address
    address internal constant AAVE_POOL_USDC = 0x11fCfe756c05AD438e312a7fd934381537D3cFfe; // TODO: Scroll Aave pool for USDC
    address internal constant AAVE_POOL_WETH = 0x11fCfe756c05AD438e312a7fd934381537D3cFfe; // TODO: Scroll Aave pool for WETH

    // Treasury & payout configuration
    address internal constant PROTOCOL_TREASURY = 0x98cF137F0d8F2C72F22fa44Ec1076D27ab0cd245; // TODO: set Treasury wallet
    address internal constant PROTOCOL_GUARDIAN = 0x98cF137F0d8F2C72F22fa44Ec1076D27ab0cd245; // TODO: guardian/operator address

    // Metadata placeholders
    string internal constant USDC_STRATEGY_URI = "ipfs://usdc-strategy";
    string internal constant WETH_STRATEGY_URI = "ipfs://weth-strategy";
    string internal constant MANUAL_STRATEGY_URI = "ipfs://manual-strategy";

    uint256 internal constant MAX_TVL_DEFAULT = type(uint256).max;

    struct Deployment {
        address roleManager;
        address strategyRegistry;
        address campaignRegistry;
        address payoutRouter;
        address vaultFactory;
        address usdcAdapter;
        address wethAdapter;
        address manualAdapter;
        uint64 usdcStrategyId;
        uint64 wethStrategyId;
        uint64 manualStrategyId;
        uint64 campaignId;
        address vault;
        address strategyManager;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        Deployment memory out;

        RoleManager roleManager = new RoleManager(SCROLL_MULTISIG);
        out.roleManager = address(roleManager);

        // Grant critical roles to the multisig and deployer as needed
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), PROTOCOL_GUARDIAN);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), SCROLL_MULTISIG);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), PROTOCOL_TREASURY);

        StrategyRegistry strategyRegistry = new StrategyRegistry(address(roleManager));
        out.strategyRegistry = address(strategyRegistry);

        CampaignRegistry campaignRegistry = new CampaignRegistry(
            address(roleManager),
            PROTOCOL_TREASURY,
            address(strategyRegistry),
            0 // minimum stake, update if needed
        );
        out.campaignRegistry = address(campaignRegistry);

        PayoutRouter payoutRouter = new PayoutRouter(
            address(roleManager),
            address(campaignRegistry),
            PROTOCOL_TREASURY
        );
        out.payoutRouter = address(payoutRouter);

        CampaignVaultFactory vaultFactory = new CampaignVaultFactory(
            address(roleManager),
            address(strategyRegistry),
            address(campaignRegistry),
            address(payoutRouter)
        );
        out.vaultFactory = address(vaultFactory);

        // Allow factory to administer campaign approvals/strategy approvals if needed
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(vaultFactory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(vaultFactory));
        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(vaultFactory));

        // === Deploy adapters ===
        AaveAdapter usdcAdapter = new AaveAdapter(
            address(roleManager),
            USDC,
            address(0), // will be reassigned when vault is deployed
            AAVE_POOL_USDC
        );
        out.usdcAdapter = address(usdcAdapter);

        AaveAdapter wethAdapter = new AaveAdapter(
            address(roleManager),
            WETH,
            address(0),
            AAVE_POOL_WETH
        );
        out.wethAdapter = address(wethAdapter);

        ManualAdapter manualAdapter = new ManualAdapter(
            address(roleManager),
            USDC, // TODO: choose asset the manual strategy manages
            address(0)
        );
        out.manualAdapter = address(manualAdapter);

        // Register strategies
        out.usdcStrategyId = strategyRegistry.createStrategy(
            USDC,
            address(usdcAdapter),
            RegistryTypes.RiskTier.Conservative,
            USDC_STRATEGY_URI,
            MAX_TVL_DEFAULT
        );

        out.wethStrategyId = strategyRegistry.createStrategy(
            WETH,
            address(wethAdapter),
            RegistryTypes.RiskTier.Moderate,
            WETH_STRATEGY_URI,
            MAX_TVL_DEFAULT
        );

        out.manualStrategyId = strategyRegistry.createStrategy(
            USDC,
            address(manualAdapter),
            RegistryTypes.RiskTier.Experimental,
            MANUAL_STRATEGY_URI,
            MAX_TVL_DEFAULT
        );

        // === Register a sample campaign ===
        address campaignCreator = vm.envAddress("CAMPAIGN_CREATOR"); // TODO: supply creator address
        address curator = vm.envAddress("CAMPAIGN_CURATOR"); // TODO: supply curator address
        address payoutWallet = vm.envAddress("CAMPAIGN_PAYOUT"); // TODO: supply payout wallet

        vm.startBroadcast(deployerKey);
        vm.prank(campaignCreator);
        uint64 campaignId = campaignRegistry.submitCampaign(
            "ipfs://nanyang-press-foundation", // metadata URI placeholder
            curator,
            payoutWallet,
            RegistryTypes.LockProfile.Minutes1
        );
        out.campaignId = campaignId;

        vm.prank(SCROLL_MULTISIG);
        campaignRegistry.approveCampaign(campaignId);

        vm.prank(SCROLL_MULTISIG);
        campaignRegistry.attachStrategy(campaignId, out.usdcStrategyId);

        CampaignVaultFactory.Deployment memory deployment = vaultFactory.deployCampaignVault(
            campaignId,
            out.usdcStrategyId,
            RegistryTypes.LockProfile.Minutes1,
            "Nanyang Press Foundation",
            "NPF-USDC",
            1e6 // minimum deposit (1 USDC)
        );
        out.vault = deployment.vault;
        out.strategyManager = deployment.strategyManager;

        // Wire adapters now that vault exists
        StrategyManager manager = StrategyManager(deployment.strategyManager);
        manager.setStrategyRegistry(address(strategyRegistry));
        manager.setPayoutRouter(address(payoutRouter));
        manager.setAdapterApproval(out.usdcAdapter, true);
        manager.setActiveAdapter(out.usdcAdapter);

        vm.stopBroadcast();
    }
}
