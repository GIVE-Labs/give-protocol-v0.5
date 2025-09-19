// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {Deploy} from "./Deploy.s.sol";
import {DeployETHVault} from "./DeployETHVault.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";

/**
 * @title DeployLocal
 * @dev Deployment script specifically for local Anvil testing
 * @notice Sets up a complete local testing environment with both USDC and ETH vaults
 */
contract DeployLocal is Script {
    function run() external {
        console.log("=== Deploying Give Protocol to Local Anvil ===");
        console.log("Chain ID:", block.chainid);

        // Deploy the main USDC contracts using Deploy script
        console.log("\n=== Deploying USDC Vault System ===");
        Deploy deployer = new Deploy();
        Deploy.Deployed memory deployed = deployer.run();

        // Deploy the ETH vault contracts using DeployETHVault script
        console.log("\n=== Deploying ETH Vault System ===");
        DeployETHVault ethDeployer = new DeployETHVault();

        // Set environment variables to reuse existing registry and router
        vm.setEnv("EXISTING_REGISTRY", vm.toString(deployed.registry));
        vm.setEnv("EXISTING_ROUTER", vm.toString(deployed.router));

        DeployETHVault.ETHVaultDeployment memory ethDeployed = ethDeployer.run();

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

        console.log("\n=== Complete Deployment Summary ===");
        console.log("Deployer:", deployer_addr);

        console.log("\n--- Token Addresses ---");
        console.log("USDC Token:", usdc);
        console.log("WETH Token:", weth);
        console.log("WBTC Token:", wbtc);
        console.log("ETH (Native):", address(0)); // Native ETH

        console.log("\n--- USDC Vault System ---");
        console.log("VAULT:", deployed.vault);
        console.log("STRATEGY_MANAGER:", deployed.manager);
        console.log("AAVE_ADAPTER:", deployed.adapter);

        console.log("\n--- ETH Vault System ---");
        console.log("ETH_VAULT:", ethDeployed.ethVault);
        console.log("ETH_VAULT_MANAGER:", ethDeployed.ethVaultManager);
        console.log("ETH_VAULT_ADAPTER:", ethDeployed.ethVaultAdapter);

        console.log("\n--- Shared Contracts ---");
        console.log("NGO_REGISTRY:", deployed.registry);
        console.log("DONATION_ROUTER:", deployed.router);

        // === Deploy Mock NGO ===
        console.log("\n=== DEPLOYING MOCK NGO ===");

        // Mock NGO details
        address mockNGOAddress = 0x1234567890123456789012345678901234567890; // Mock NGO address
        string memory mockMetadataCid = "bafkreigojgaflin5ulvlej3uaurs36h5mskd3l4gxov4qsce3qhajwrkzy"; // Real IPFS CID from Pinata
        bytes32 mockKycHash = keccak256("MOCK_KYC_VERIFICATION_HASH"); // Mock KYC hash
        address mockAttestor = deployer_addr; // Use deployer as attestor for testing

        // Register the mock NGO
        NGORegistry registry = NGORegistry(deployed.registry);

        // Ensure deployer has NGO_MANAGER_ROLE
        vm.startBroadcast(deployerKey);
        if (!registry.hasRole(registry.NGO_MANAGER_ROLE(), deployer_addr)) {
            registry.grantRole(registry.NGO_MANAGER_ROLE(), deployer_addr);
            console.log("Granted NGO_MANAGER_ROLE to deployer");
        }

        registry.addNGO(mockNGOAddress, mockMetadataCid, mockKycHash, mockAttestor);
        vm.stopBroadcast();

        console.log("Mock NGO registered:");
        console.log("  Address:", mockNGOAddress);
        console.log("  Metadata CID:", mockMetadataCid);
        console.log("  KYC Hash:", vm.toString(mockKycHash));
        console.log("  Attestor:", mockAttestor);
        console.log("  Is Approved:", registry.isNGOApproved(mockNGOAddress));
        console.log("  Current NGO:", registry.getCurrentNGO());

        console.log("\n=== Frontend Config Format ===");
        console.log("Copy these addresses to frontend/src/config/local.ts:");
        console.log("");
        console.log("export const LOCAL_CONTRACT_ADDRESSES = {");
        console.log("  // Protocol contracts - USDC Vault");
        console.log(string.concat("  VAULT: \"", vm.toString(deployed.vault), "\","));
        console.log(string.concat("  AAVE_ADAPTER: \"", vm.toString(deployed.adapter), "\","));
        console.log(string.concat("  STRATEGY_MANAGER: \"", vm.toString(deployed.manager), "\","));
        console.log("");
        console.log("  // ETH Vault contracts");
        console.log(string.concat("  ETH_VAULT: \"", vm.toString(ethDeployed.ethVault), "\","));
        console.log(string.concat("  ETH_VAULT_MANAGER: \"", vm.toString(ethDeployed.ethVaultManager), "\","));
        console.log(string.concat("  ETH_VAULT_ADAPTER: \"", vm.toString(ethDeployed.ethVaultAdapter), "\","));
        console.log("");
        console.log("  // Shared contracts");
        console.log(string.concat("  NGO_REGISTRY: \"", vm.toString(deployed.registry), "\","));
        console.log(string.concat("  DONATION_ROUTER: \"", vm.toString(deployed.router), "\","));
        console.log("");
        console.log("  // Mock tokens for local testing");
        console.log(string.concat("  ETH: \"", vm.toString(address(0)), "\", // Native ETH"));
        console.log(string.concat("  USDC: \"", vm.toString(usdc), "\","));
        console.log(string.concat("  WETH: \"", vm.toString(weth), "\","));
        console.log("");
        console.log("  // Mock NGO for testing");
        console.log(string.concat("  MOCK_NGO: \"", vm.toString(mockNGOAddress), "\","));
        console.log("} as const;");

        console.log("\n=== Token Balances ===");
        console.log("Deployer USDC balance:", IERC20(usdc).balanceOf(deployer_addr));
        console.log("Deployer WETH balance:", IERC20(weth).balanceOf(deployer_addr));
        console.log("Deployer WBTC balance:", IERC20(wbtc).balanceOf(deployer_addr));
        console.log("Deployer ETH balance:", deployer_addr.balance);
        console.log("Mock NGO:", mockNGOAddress);

        console.log("\n=== Local Suite Deployment Complete ===");
        console.log("Both USDC and ETH vault systems deployed!");
        console.log("Ready for testing with Anvil!");
    }
}
