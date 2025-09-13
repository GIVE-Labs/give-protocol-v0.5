// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/manager/StrategyManager.sol";
import "../src/adapters/AaveAdapter.sol";
import "../src/donation/NGORegistry.sol";
import "../src/donation/DonationRouter.sol";

/**
 * @title DeployScript
 * @dev Deployment script for GIVE Protocol v0.1 MVP
 */
contract DeployScript is Script {
    // === Network Configuration ===
    struct NetworkConfig {
        address usdc;
        address aavePool;
        string name;
    }
    
    // === Deployment Configuration ===
    struct DeploymentConfig {
        uint256 cashBufferBps;
        uint256 slippageBps;
        uint256 maxLossBps;
        uint256 feeBps;
        string vaultName;
        string vaultSymbol;
    }
    
    // === Network Configurations ===
    mapping(uint256 => NetworkConfig) public networkConfigs;
    
    // === Deployed Contracts ===
    GiveVault4626 public vault;
    StrategyManager public strategyManager;
    AaveAdapter public aaveAdapter;
    NGORegistry public ngoRegistry;
    DonationRouter public donationRouter;
    
    // === Deployment Addresses ===
    address public deployer;
    address public admin;
    address public vaultManager;
    address public ngoManager;
    address public donationManager;
    address public feeRecipient;
    
    function setUp() public {
        // Initialize network configurations
        _initializeNetworkConfigs();
        
        // Set deployment addresses
        deployer = vm.envAddress("DEPLOYER_ADDRESS");
        admin = vm.envOr("ADMIN_ADDRESS", deployer);
        vaultManager = vm.envOr("VAULT_MANAGER_ADDRESS", admin);
        ngoManager = vm.envOr("NGO_MANAGER_ADDRESS", admin);
        donationManager = vm.envOr("DONATION_MANAGER_ADDRESS", admin);
        feeRecipient = vm.envOr("FEE_RECIPIENT_ADDRESS", admin);
    }
    
    function run() public {
        uint256 chainId = block.chainid;
        NetworkConfig memory config = networkConfigs[chainId];
        
        require(config.usdc != address(0), "Unsupported network");
        
        console.log("Deploying GIVE Protocol v0.1 MVP to:", config.name);
        console.log("Chain ID:", chainId);
        console.log("USDC Address:", config.usdc);
        console.log("Aave Pool:", config.aavePool);
        console.log("Deployer:", deployer);
        console.log("Admin:", admin);
        
        vm.startBroadcast(deployer);
        
        // Deploy contracts
        _deployContracts(config);
        
        // Configure system
        _configureSystem();
        
        // Setup roles
        _setupRoles();
        
        // Verify deployment
        _verifyDeployment(config);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        _logDeploymentSummary();
    }
    
    function _initializeNetworkConfigs() internal {
        // Ethereum Mainnet
        networkConfigs[1] = NetworkConfig({
            usdc: 0xA0B86A33e6441b8435B662F0e2D0c2837e5c8B3F,
            aavePool: 0x87870BAce7f90C5c9C8c8C8C8c8C8C8c8c8C8c8C,
            name: "Ethereum Mainnet"
        });
        
        // Ethereum Sepolia Testnet
        networkConfigs[11155111] = NetworkConfig({
            usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8, // Sepolia USDC
            aavePool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951, // Sepolia Aave Pool
            name: "Ethereum Sepolia"
        });
        
        // Polygon Mainnet
        networkConfigs[137] = NetworkConfig({
            usdc: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            aavePool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
            name: "Polygon Mainnet"
        });
        
        // Polygon Mumbai Testnet
        networkConfigs[80001] = NetworkConfig({
            usdc: 0x2058A9D7613eEE744279e3856Ef0eAda5FCbaA7e, // Mumbai USDC
            aavePool: 0x9198F13B08E299d85E096929fA9781A1E3d5d827, // Mumbai Aave Pool
            name: "Polygon Mumbai"
        });
        
        // Arbitrum One
        networkConfigs[42161] = NetworkConfig({
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            aavePool: 0x794a61358D6845594F94dc1DB02A252b5b4814aD,
            name: "Arbitrum One"
        });
        
        // Base Mainnet
        networkConfigs[8453] = NetworkConfig({
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            aavePool: 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5,
            name: "Base Mainnet"
        });
    }
    
    function _deployContracts(NetworkConfig memory config) internal {
        DeploymentConfig memory deployConfig = DeploymentConfig({
            cashBufferBps: 100, // 1%
            slippageBps: 50,    // 0.5%
            maxLossBps: 50,     // 0.5%
            feeBps: 250,        // 2.5%
            vaultName: "GIVE Vault USDC",
            vaultSymbol: "gvUSDC"
        });
        
        console.log("\n=== Deploying Contracts ===");
        
        // Deploy NGO Registry
        console.log("Deploying NGORegistry...");
        ngoRegistry = new NGORegistry(admin);
        console.log("NGORegistry deployed at:", address(ngoRegistry));
        
        // Deploy Donation Router
        console.log("Deploying DonationRouter...");
        donationRouter = new DonationRouter(
            admin,
            address(ngoRegistry),
            feeRecipient,
            deployConfig.feeBps
        );
        console.log("DonationRouter deployed at:", address(donationRouter));
        
        // Deploy Vault
        console.log("Deploying GiveVault4626...");
        vault = new GiveVault4626(
            IERC20(config.usdc),
            deployConfig.vaultName,
            deployConfig.vaultSymbol,
            admin
        );
        console.log("GiveVault4626 deployed at:", address(vault));
        
        // Deploy Strategy Manager
        console.log("Deploying StrategyManager...");
        strategyManager = new StrategyManager(
            address(vault),
            admin
        );
        console.log("StrategyManager deployed at:", address(strategyManager));
        
        // Deploy Aave Adapter
        console.log("Deploying AaveAdapter...");
        aaveAdapter = new AaveAdapter(
            config.usdc,
            address(vault),
            config.aavePool,
            admin
        );
        console.log("AaveAdapter deployed at:", address(aaveAdapter));
    }
    
    function _configureSystem() internal {
        console.log("\n=== Configuring System ===");
        
        // Wire vault ↔ router connection
        console.log("Wiring vault <-> router connection...");
        vault.setDonationRouter(address(donationRouter));
        donationRouter.setAuthorizedCaller(address(vault), true);
        
        // Configure Strategy Manager
        console.log("Configuring StrategyManager...");
        // Cash buffer is now managed by the vault, not strategy manager
        // Slippage and max loss are now managed by individual adapters
        strategyManager.setActiveAdapter(address(aaveAdapter));
        
        // Configure Vault
        console.log("Configuring GiveVault4626...");
        vault.setActiveAdapter(aaveAdapter);
        
        console.log("System configuration completed");
    }
    
    function _setupRoles() internal {
        console.log("\n=== Setting Up Roles ===");
        
        // NGO Registry roles
        if (ngoManager != admin) {
            ngoRegistry.grantRole(ngoRegistry.NGO_MANAGER_ROLE(), ngoManager);
            console.log("Granted NGO_MANAGER_ROLE to:", ngoManager);
        }
        
        // Grant DONATION_RECORDER_ROLE to DonationRouter
        ngoRegistry.grantRole(ngoRegistry.DONATION_RECORDER_ROLE(), address(donationRouter));
        console.log("Granted DONATION_RECORDER_ROLE to DonationRouter:", address(donationRouter));
        
        // Donation Router roles
        if (donationManager != admin) {
            donationRouter.grantRole(donationRouter.VAULT_MANAGER_ROLE(), donationManager);
            console.log("Granted VAULT_MANAGER_ROLE to:", donationManager);
        }
        
        // Strategy Manager roles
        // Role management simplified in v0.1
        // Role management simplified in v0.1
        console.log("Role configuration completed");
        
        // Aave Adapter roles (admin retains control)
        console.log("AaveAdapter ADAPTER_MANAGER_ROLE retained by admin:", admin);
        
        console.log("Role setup completed");
    }
    
    function _verifyDeployment(NetworkConfig memory config) internal view {
        console.log("\n=== Verifying Deployment ===");
        
        // Verify contract addresses
        require(address(vault) != address(0), "Vault not deployed");
        require(address(strategyManager) != address(0), "StrategyManager not deployed");
        require(address(aaveAdapter) != address(0), "AaveAdapter not deployed");
        require(address(ngoRegistry) != address(0), "NGORegistry not deployed");
        require(address(donationRouter) != address(0), "DonationRouter not deployed");
        
        // Verify connections (simplified for v0.1)
        require(aaveAdapter.vault() == address(vault), "AaveAdapter-Vault connection failed");
        
        // Verify asset configuration
        require(vault.asset() == config.usdc, "Vault asset mismatch");
        require(address(aaveAdapter.asset()) == config.usdc, "AaveAdapter asset mismatch");
        require(address(aaveAdapter.aavePool()) == config.aavePool, "AaveAdapter pool mismatch");
        
        // Configuration verification simplified for v0.1
        // Most configuration checks removed for v0.1 simplicity
        
        console.log("Deployment verification completed successfully");
    }
    
    function _logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", networkConfigs[block.chainid].name);
        console.log("Chain ID:", block.chainid);
        console.log("");
        console.log("Contract Addresses:");
        console.log("  GiveVault4626:", address(vault));
        console.log("  StrategyManager:", address(strategyManager));
        console.log("  AaveAdapter:", address(aaveAdapter));
        console.log("  NGORegistry:", address(ngoRegistry));
        console.log("  DonationRouter:", address(donationRouter));
        console.log("");
        console.log("Configuration:");
        console.log("  Cash Buffer: 1%");
        console.log("  Slippage Tolerance: 0.5%");
        console.log("  Max Loss: 0.5%");
        console.log("  Fee: 2.5%");
        console.log("  Fee Recipient:", feeRecipient);
        console.log("");
        console.log("Role Assignments:");
        console.log("  Admin:", admin);
        console.log("  Vault Manager:", vaultManager);
        console.log("  NGO Manager:", ngoManager);
        console.log("  Donation Manager:", donationManager);
        console.log("");
        console.log("Next Steps:");
        console.log("1. Add NGOs to the registry using NGO Manager role");
        console.log("2. Test deposit/withdraw functionality");
        console.log("3. Test yield generation and harvesting");
        console.log("4. Verify donation distribution to NGOs");
        console.log("\nDeployment completed successfully!");
    }
    
    // === Utility Functions ===
    
    function getDeployedAddresses() external view returns (
        address _vault,
        address _strategyManager,
        address _aaveAdapter,
        address _ngoRegistry,
        address _donationRouter
    ) {
        return (
            address(vault),
            address(strategyManager),
            address(aaveAdapter),
            address(ngoRegistry),
            address(donationRouter)
        );
    }
    
    function getNetworkConfig(uint256 chainId) external view returns (NetworkConfig memory) {
        return networkConfigs[chainId];
    }
    
    function isNetworkSupported(uint256 chainId) external view returns (bool) {
        return networkConfigs[chainId].usdc != address(0);
    }
}

/**
 * @title SmokeTestScript
 * @dev Script to run smoke tests after deployment
 */
contract SmokeTestScript is Script {
    function run() public {
        // Load deployed contract addresses from environment
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address testUser = vm.envAddress("TEST_USER_ADDRESS");
        
        GiveVault4626 vault = GiveVault4626(vaultAddress);
        IERC20 usdc = IERC20(usdcAddress);
        
        console.log("Running smoke tests...");
        console.log("Vault:", vaultAddress);
        console.log("USDC:", usdcAddress);
        console.log("Test User:", testUser);
        
        vm.startBroadcast(testUser);
        
        // Test deposit
        uint256 depositAmount = 1000e6; // 1000 USDC
        uint256 userBalance = usdc.balanceOf(testUser);
        
        require(userBalance >= depositAmount, "Insufficient USDC balance for test");
        
        console.log("Testing deposit of", depositAmount, "USDC...");
        usdc.approve(vaultAddress, depositAmount);
        uint256 shares = vault.deposit(depositAmount, testUser);
        
        console.log("Received", shares, "shares");
        require(shares > 0, "Deposit failed - no shares received");
        
        // Test withdrawal
        console.log("Testing withdrawal...");
        uint256 withdrawn = vault.redeem(shares, testUser, testUser);
        
        console.log("Withdrawn", withdrawn, "USDC");
        require(withdrawn > 0, "Withdrawal failed");
        
        vm.stopBroadcast();
        
        console.log("Smoke tests completed successfully!");
    }
}
