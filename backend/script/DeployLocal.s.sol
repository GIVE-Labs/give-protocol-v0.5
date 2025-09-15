// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {Deploy} from "./Deploy.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployLocal
 * @dev Deployment script specifically for local Anvil testing
 * @notice Sets up a complete local testing environment with mock tokens and yield adapter
 */
contract DeployLocal is Script {
    function run() external {
        console.log("=== Deploying Give Protocol to Local Anvil ===");
        console.log("Chain ID:", block.chainid);
        
        // Deploy the main contracts using Deploy script
        Deploy deployer = new Deploy();
        Deploy.Deployed memory deployed = deployer.run();
        
        // Get network config for additional setup
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
        
        address deployer_addr = vm.addr(deployerKey);
        
        console.log("\n=== Deployment Summary ===");
        console.log("Deployer:", deployer_addr);
        console.log("USDC Token:", usdc);
        console.log("WETH Token:", weth);
        console.log("WBTC Token:", wbtc);
        console.log("Vault:", deployed.vault);
        console.log("StrategyManager:", deployed.manager);
        console.log("MockYieldAdapter:", deployed.adapter);
        console.log("NGORegistry:", deployed.registry);
        console.log("DonationRouter:", deployed.router);
        
        console.log("\n=== Token Balances ===");
        console.log("Deployer USDC balance:", IERC20(usdc).balanceOf(deployer_addr));
        console.log("Deployer WETH balance:", IERC20(weth).balanceOf(deployer_addr));
        console.log("Deployer WBTC balance:", IERC20(wbtc).balanceOf(deployer_addr));
        
        console.log("\n=== Local Suite Deployment Complete ===");
        console.log("Ready for testing with Anvil!");
    }
}