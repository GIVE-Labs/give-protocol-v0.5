// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GiveVault4626} from "../src/vault/GiveVault4626.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";
import {MockYieldAdapter} from "../src/adapters/MockYieldAdapter.sol";
import {IYieldAdapter} from "../src/adapters/IYieldAdapter.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";
import {DonationRouter} from "../src/donation/DonationRouter.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @title DeployETHVault
 * @dev Deployment script for ETH vault with WETH as underlying asset
 * @notice Deploys a complete ETH staking system with Aave yield generation
 */
contract DeployETHVault is Script {
    struct ETHVaultDeployment {
        address ethVault;
        address ethVaultManager;
        address ethVaultAdapter;
        address registry;
        address router;
        address weth;
    }

    function run() external returns (ETHVaultDeployment memory deployment) {
        console.log("=== Deploying ETH Vault System ===");
        console.log("Chain ID:", block.chainid);
        
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

        // Configuration parameters
        address admin = vm.envOr("ADMIN_ADDRESS", vm.addr(deployerKey));
        address feeRecipient = vm.envOr("FEE_RECIPIENT_ADDRESS", admin);
        
        // ETH Vault specific parameters
        string memory ethVaultName = vm.envOr("ETH_VAULT_NAME", string("GIVE ETH Vault"));
        string memory ethVaultSymbol = vm.envOr("ETH_VAULT_SYMBOL", string("gvETH"));
        
        uint256 cashBufferBps = vm.envOr("CASH_BUFFER_BPS", uint256(100)); // 1%
        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(50)); // 0.5%
        uint256 maxLossBps = vm.envOr("MAX_LOSS_BPS", uint256(50)); // 0.5%
        uint256 feeBps = vm.envOr("FEE_BPS", uint256(250)); // 2.5%

        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);

        console.log("Deployer address:", deployer);
        console.log("WETH address:", weth);
        console.log("Aave Pool address:", aavePool);

        // Deploy or reuse existing registry and router
        NGORegistry registry;
        DonationRouter router;
        
        // Check if we should reuse existing contracts
        address existingRegistry = vm.envOr("EXISTING_REGISTRY", address(0));
        address existingRouter = vm.envOr("EXISTING_ROUTER", address(0));
        
        if (existingRegistry != address(0) && existingRouter != address(0)) {
            console.log("Using existing Registry:", existingRegistry);
            console.log("Using existing Router:", existingRouter);
            registry = NGORegistry(existingRegistry);
            router = DonationRouter(payable(existingRouter));
        } else {
            console.log("Deploying new Registry and Router...");
            registry = new NGORegistry(deployer);
            router = new DonationRouter(deployer, address(registry), feeRecipient, admin, feeBps);
            
            // Setup registry roles
            registry.grantRole(registry.NGO_MANAGER_ROLE(), admin);
            registry.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));
        }

        // Deploy ETH Vault with WETH as underlying asset
        console.log("Deploying ETH Vault...");
        GiveVault4626 ethVault = new GiveVault4626(
            IERC20(weth), 
            ethVaultName, 
            ethVaultSymbol, 
            deployer
        );
        
        // Set WETH as wrapped native for ETH convenience methods
        ethVault.setWrappedNative(weth);
        
        // Deploy Strategy Manager for ETH Vault
        console.log("Deploying ETH Vault Strategy Manager...");
        StrategyManager ethVaultManager = new StrategyManager(address(ethVault), deployer);
        
        // Deploy appropriate adapter based on network
        IYieldAdapter ethVaultAdapter;
        if (block.chainid == 31337) {
            // Use MockYieldAdapter for local testing
            console.log("Deploying MockYieldAdapter for ETH Vault (local testing)...");
            ethVaultAdapter = new MockYieldAdapter(weth, address(ethVault), deployer);
        } else {
            // Use AaveAdapter for live networks
            console.log("Deploying AaveAdapter for ETH Vault (live network)...");
            ethVaultAdapter = new AaveAdapter(weth, address(ethVault), aavePool, deployer);
        }

        // Configure ETH Vault
        console.log("Configuring ETH Vault...");
        
        // Grant roles
        ethVault.grantRole(ethVault.VAULT_MANAGER_ROLE(), address(ethVaultManager));
        ethVault.setDonationRouter(address(router));
        router.setAuthorizedCaller(address(ethVault), true);

        // Configure Strategy Manager
        ethVaultManager.setAdapterApproval(address(ethVaultAdapter), true);
        ethVaultManager.setActiveAdapter(address(ethVaultAdapter));
        ethVaultManager.updateVaultParameters(cashBufferBps, slippageBps, maxLossBps);
        ethVaultManager.setDonationRouter(address(router));

        vm.stopBroadcast();

        // Log deployment addresses
        console.log("\n=== ETH Vault Deployment Complete ===");
        console.log("ETH Vault:", address(ethVault));
        console.log("ETH Vault Strategy Manager:", address(ethVaultManager));
        console.log("ETH Vault Adapter:", address(ethVaultAdapter));
        console.log("NGO Registry:", address(registry));
        console.log("Donation Router:", address(router));
        console.log("WETH Token:", weth);
        
        // Verify configuration
        console.log("\n=== Configuration Verification ===");
        console.log("Vault asset:", address(ethVault.asset()));
        console.log("Vault wrapped native:", ethVault.wrappedNative());
        console.log("Active adapter:", address(ethVault.activeAdapter()));
        console.log("Donation router:", ethVault.donationRouter());
        
        (uint256 cashBuffer, uint256 slippage, uint256 maxLoss,,) = ethVault.getConfiguration();
        console.log("Cash buffer (bps):", cashBuffer);
        console.log("Slippage (bps):", slippage);
        console.log("Max loss (bps):", maxLoss);

        return ETHVaultDeployment({
            ethVault: address(ethVault),
            ethVaultManager: address(ethVaultManager),
            ethVaultAdapter: address(ethVaultAdapter),
            registry: address(registry),
            router: address(router),
            weth: weth
        });
    }

    /**
     * @dev Helper function to verify deployment
     */
    function verifyDeployment(ETHVaultDeployment memory deployment) external view {
        console.log("\n=== Deployment Verification ===");
        
        GiveVault4626 vault = GiveVault4626(payable(deployment.ethVault));
        
        // Check basic configuration
        require(address(vault.asset()) == deployment.weth, "Asset mismatch");
        require(vault.wrappedNative() == deployment.weth, "Wrapped native mismatch");
        require(address(vault.activeAdapter()) == deployment.ethVaultAdapter, "Adapter mismatch");
        require(vault.donationRouter() == deployment.router, "Router mismatch");
        
        console.log("All verifications passed!");
    }
}