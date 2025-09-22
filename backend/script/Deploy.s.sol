// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GiveVault4626} from "../src/vault/GiveVault4626.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";
import {MockYieldAdapter} from "../src/adapters/MockYieldAdapter.sol";
import {IYieldAdapter} from "../src/interfaces/IYieldAdapter.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";
import {DonationRouter} from "../src/donation/DonationRouter.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract Deploy is Script {
    struct Deployed {
        address vault;
        address manager;
        address adapter;
        address registry;
        address router;
    }

    function run() external returns (Deployed memory out) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address weth,
            address wbtc,
            address usdc,
            address aavePool,
            uint256 deployerKey
        ) = helperConfig.getActiveNetworkConfig();

        // Use environment variables if available, otherwise use msg.sender for account-based deployment
        address admin = vm.envOr("ADMIN_ADDRESS", deployerKey == 0 ? msg.sender : vm.addr(deployerKey));
        address assetAddress = vm.envOr("ASSET_ADDRESS", usdc);

        // Optional naming overrides for the vault
        string memory assetName = vm.envOr("ASSET_NAME", string("GIVE Vault USDC"));
        string memory assetSymbol = vm.envOr("ASSET_SYMBOL", string("gvUSDC"));
        address feeRecipient = vm.envOr("FEE_RECIPIENT_ADDRESS", admin);

        uint256 cashBufferBps = vm.envOr("CASH_BUFFER_BPS", uint256(100)); // 1%
        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(50)); // 0.5%
        uint256 maxLossBps = vm.envOr("MAX_LOSS_BPS", uint256(50)); // 0.5%
        uint256 feeBps = vm.envOr("FEE_BPS", uint256(250)); // 2.5%

        // Handle deployment based on whether we're using private key or account
        address deployer;
        if (deployerKey == 0) {
            // Account-based deployment
            vm.startBroadcast();
            deployer = msg.sender;
        } else {
            // Private key deployment
            deployer = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        }

        NGORegistry registry = new NGORegistry(admin); // Use environment admin as admin
        RoleManager roleManager = new RoleManager(deployer);
        if (admin != deployer) {
            roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), admin);
        }
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), deployer);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), deployer);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), deployer);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), deployer);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), deployer);
        if (admin != deployer) {
            roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
            roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
            roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
            roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
            roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        }

        DonationRouter router = new DonationRouter(
            address(roleManager),
            address(registry),
            feeRecipient,
            admin,
            feeBps
        );
        roleManager.grantRole(roleManager.ROLE_DONATION_RECORDER(), address(router));

        GiveVault4626 vault = new GiveVault4626(IERC20(assetAddress), assetName, assetSymbol, address(roleManager));
        StrategyManager manager = new StrategyManager(address(vault), address(roleManager));
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), address(manager));

        // Use MockYieldAdapter for Anvil (chainid 31337), AaveAdapter for other networks
        IYieldAdapter adapter;
        if (block.chainid == 31337) {
            adapter = new MockYieldAdapter(assetAddress, address(vault), admin);
            console.log("Using MockYieldAdapter for local testing");
        } else {
            adapter = new AaveAdapter(assetAddress, address(vault), aavePool, admin);
            console.log("Using AaveAdapter for live network");
        }

        // Wire roles & params
        console.log("Deployer address:", deployer);
        console.log("Admin address:", admin);
        router.setAuthorizedCaller(address(vault), true);

        manager.setAdapterApproval(address(adapter), true);
        manager.setActiveAdapter(address(adapter));
        manager.updateVaultParameters(cashBufferBps, slippageBps, maxLossBps);
        manager.setDonationRouter(address(router));

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("StrategyManager:", address(manager));
        console.log("RoleManager:", address(roleManager));
        console.log("AaveAdapter:", address(adapter));
        console.log("NGORegistry:", address(registry));
        console.log("DonationRouter:", address(router));

        return Deployed({
            vault: address(vault),
            manager: address(manager),
            adapter: address(adapter),
            registry: address(registry),
            router: address(router)
        });
    }
}
