// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {Deploy} from "./Deploy.s.sol";
import {DeployETHVault} from "./DeployETHVault.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployLocal is Script {
    function run() external {
        console.log("=== Deploying GIVE Protocol (Local) ===");
        console.log("Chain ID:", block.chainid);

        // Step 1: Deploy USDC stack
        console.log("\n=== Deploying USDC Campaign Infrastructure ===");
        Deploy deployer = new Deploy();
        Deploy.Deployed memory usdDeployment = deployer.run();

        // Step 2: Reuse shared infrastructure for ETH deployment
        console.log("\n=== Deploying WETH Campaign Infrastructure (Reusing shared contracts) ===");
        vm.setEnv("EXISTING_ROLE_MANAGER", vm.toString(usdDeployment.roleManager));
        vm.setEnv("EXISTING_STRATEGY_REGISTRY", vm.toString(usdDeployment.strategyRegistry));
        vm.setEnv("EXISTING_CAMPAIGN_REGISTRY", vm.toString(usdDeployment.campaignRegistry));
        vm.setEnv("EXISTING_PAYOUT_ROUTER", vm.toString(usdDeployment.payoutRouter));
        vm.setEnv("EXISTING_VAULT_FACTORY", vm.toString(usdDeployment.vaultFactory));

        DeployETHVault ethDeployer = new DeployETHVault();
        DeployETHVault.ETHVaultDeployment memory ethDeployment = ethDeployer.run();

        HelperConfig helperConfig = new HelperConfig();
        (,, address weth, address wbtc, address usdc,, uint256 deployerKey) = helperConfig.getActiveNetworkConfig();

        address deployerAddress = vm.addr(deployerKey);

        console.log("\n=== Deployment Summary ===");
        console.log("Deployer:", deployerAddress);
        console.log("\n--- Shared Contracts ---");
        console.log("RoleManager:", usdDeployment.roleManager);
        console.log("StrategyRegistry:", usdDeployment.strategyRegistry);
        console.log("CampaignRegistry:", usdDeployment.campaignRegistry);
        console.log("PayoutRouter:", usdDeployment.payoutRouter);
        console.log("CampaignVaultFactory:", usdDeployment.vaultFactory);

        console.log("\n--- USDC Campaign ---");
        console.log("Strategy ID:", usdDeployment.strategyId);
        console.log("Campaign ID:", usdDeployment.campaignId);
        console.log("Campaign Vault:", usdDeployment.campaignVault);
        console.log("Strategy Manager:", usdDeployment.strategyManager);
        console.log("Adapter:", usdDeployment.adapter);

        console.log("\n--- WETH Campaign ---");
        console.log("Strategy ID:", ethDeployment.strategyId);
        console.log("Campaign ID:", ethDeployment.campaignId);
        console.log("Campaign Vault:", ethDeployment.campaignVault);
        console.log("Strategy Manager:", ethDeployment.strategyManager);
        console.log("Adapter:", ethDeployment.adapter);

        console.log("\n--- Token References ---");
        console.log("USDC:", usdc);
        console.log("WETH:", weth);
        console.log("WBTC:", wbtc);

        console.log("\n=== Local Deployment Complete ===");
        console.log("Protocol ready for integration testing.");
    }
}
