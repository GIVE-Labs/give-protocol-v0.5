// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Bootstrap.s.sol";
import "./HelperConfig.s.sol";
import "../src/adapters/AaveAdapter.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";

/// @title DeployBaseSepolia
/// @notice Deployment script for Base Sepolia testnet with WETH + Aave V3
/// @dev This script:
///      1. Deploys core protocol via Bootstrap
///      2. Registers WETH strategy with Aave adapter
///      3. Creates sample climate action campaign
///      4. Deploys campaign vault
///      5. Logs all addresses for frontend integration
contract DeployBaseSepolia is Script {
    struct BaseSepoliaDeployment {
        // Core contracts
        address acl;
        address core;
        address router;
        address strategyRegistry;
        address campaignRegistry;
        address vaultFactory;
        // Vaults and adapters
        address wethVault;
        address aaveAdapter;
        address campaignVault;
        // Assets
        address weth;
        address aavePool;
        // IDs
        bytes32 strategyId;
        bytes32 campaignId;
        bytes32 vaultId;
    }

    /// @notice Main entry point for forge script
    function run() external returns (BaseSepoliaDeployment memory deployment) {
        // Load Base Sepolia config
        require(
            block.chainid == 84532,
            "Must deploy on Base Sepolia (chainId 84532)"
        );

        HelperConfig helper = new HelperConfig();
        (, , address weth, , address usdc, address aavePool, ) = helper
            .getActiveNetworkConfig();

        require(weth != address(0), "WETH address not configured");
        require(aavePool != address(0), "Aave pool address not configured");

        console.log("\n=== Base Sepolia Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("WETH:", weth);
        console.log("Aave V3 Pool:", aavePool);
        console.log("Deployer:", msg.sender);

        // Deploy core protocol via Bootstrap (handles its own broadcast)
        Bootstrap bootstrap = new Bootstrap();
        Bootstrap.Deployment memory coreDeployment = bootstrap.run();

        console.log("\n--- Core Protocol Deployed ---");
        console.log("ACL Manager:", coreDeployment.acl);
        console.log("Protocol Core:", coreDeployment.core);
        console.log("Payout Router:", coreDeployment.router);
        console.log("Strategy Registry:", coreDeployment.strategyRegistry);
        console.log("Campaign Registry:", coreDeployment.campaignRegistry);
        console.log("Vault Factory:", coreDeployment.vaultFactory);

        // Start broadcast for testnet-specific deployments
        // Bootstrap has already stopped its broadcast, so we need to start a new one
        vm.startBroadcast();

        // Deploy Aave adapter for WETH
        AaveAdapter aaveAdapter = new AaveAdapter(
            weth, // asset (WETH)
            coreDeployment.vault, // vault
            aavePool, // Aave V3 pool
            coreDeployment.admin // admin
        );

        console.log("\n--- Aave Adapter Deployed ---");
        console.log("Aave Adapter:", address(aaveAdapter));

        // 3. Register WETH strategy with Aave adapter
        StrategyRegistry strategyRegistry = StrategyRegistry(
            coreDeployment.strategyRegistry
        );

        bytes32 strategyId = keccak256("strategy.weth.aave.conservative");
        StrategyRegistry.StrategyInput memory strategyInput = StrategyRegistry
            .StrategyInput({
                id: strategyId,
                adapter: address(aaveAdapter),
                riskTier: bytes32("tier.low"),
                maxTvl: 10 ether, // 10 ETH cap for testnet
                metadataHash: keccak256("strategy.weth.aave.metadata")
            });

        strategyRegistry.registerStrategy(strategyInput);

        console.log("\n--- Strategy Registered ---");
        console.log("Strategy ID:", vm.toString(strategyId));
        console.log("Name: WETH Conservative Yield (Aave V3)");
        console.log("Risk Tier: Low");
        console.log("Max TVL: 10 ETH");

        // 4. Create sample campaign
        CampaignRegistry campaignRegistry = CampaignRegistry(
            coreDeployment.campaignRegistry
        );

        bytes32 campaignId = keccak256("campaign.climate.action.001");
        address payoutRecipient = coreDeployment.admin; // Use admin as recipient for testing

        CampaignRegistry.CampaignInput memory campaignInput = CampaignRegistry
            .CampaignInput({
                id: campaignId,
                payoutRecipient: payoutRecipient,
                strategyId: strategyId,
                metadataHash: keccak256("campaign.metadata"),
                metadataCID: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                targetStake: 5 ether, // 5 ETH fundraising goal
                minStake: 0.01 ether, // 0.01 ETH minimum stake
                fundraisingStart: uint64(block.timestamp),
                fundraisingEnd: uint64(block.timestamp + 90 days) // 90 day fundraising period
            });

        campaignRegistry.submitCampaign(campaignInput);
        campaignRegistry.approveCampaign(campaignId, coreDeployment.admin); // Admin as curator

        console.log("\n--- Campaign Created ---");
        console.log("Campaign ID:", vm.toString(campaignId));
        console.log("Payout Recipient:", payoutRecipient);
        console.log("Target Stake: 5 ETH");
        console.log("Min Stake: 0.01 ETH");
        console.log("  Fundraising Period: 90 days");
        console.log("Status: Approved");

        // Stop broadcast before file I/O
        vm.stopBroadcast();

        // Package deployment info
        deployment = BaseSepoliaDeployment({
            acl: coreDeployment.acl,
            core: coreDeployment.core,
            router: coreDeployment.router,
            strategyRegistry: coreDeployment.strategyRegistry,
            campaignRegistry: coreDeployment.campaignRegistry,
            vaultFactory: coreDeployment.vaultFactory,
            wethVault: coreDeployment.vault,
            aaveAdapter: address(aaveAdapter),
            campaignVault: coreDeployment.campaignVault,
            weth: weth,
            aavePool: aavePool,
            strategyId: strategyId,
            campaignId: campaignId,
            vaultId: coreDeployment.vaultId
        });

        // 6. Log deployment summary
        _logDeploymentSummary(deployment);

        // 7. Save to file for frontend integration
        _saveDeploymentConfig(deployment);

        return deployment;
    }

    function _toArray(address addr) private pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }

    function _logDeploymentSummary(
        BaseSepoliaDeployment memory deployment
    ) private view {
        console.log("\n");
        console.log(
            "================================================================================"
        );
        console.log(
            "     GIVE Protocol - Base Sepolia Testnet Deployment Complete"
        );
        console.log(
            "================================================================================"
        );
        console.log("");
        console.log("Core Contracts:");
        console.log("  ACL Manager:         ", deployment.acl);
        console.log("  Protocol Core:       ", deployment.core);
        console.log("  Payout Router:       ", deployment.router);
        console.log("  Strategy Registry:   ", deployment.strategyRegistry);
        console.log("  Campaign Registry:   ", deployment.campaignRegistry);
        console.log("  Vault Factory:       ", deployment.vaultFactory);
        console.log("");
        console.log("Vaults & Adapters:");
        console.log("  WETH Vault:          ", deployment.wethVault);
        console.log("  Aave Adapter:        ", deployment.aaveAdapter);
        console.log("  Campaign Vault:      ", deployment.campaignVault);
        console.log("");
        console.log("Assets:");
        console.log("  WETH:                ", deployment.weth);
        console.log("  Aave V3 Pool:        ", deployment.aavePool);
        console.log("");
        console.log("Identifiers:");
        console.log(
            "  Strategy ID:         ",
            vm.toString(deployment.strategyId)
        );
        console.log(
            "  Campaign ID:         ",
            vm.toString(deployment.campaignId)
        );
        console.log("  Vault ID:            ", vm.toString(deployment.vaultId));
        console.log("");
        console.log("Next Steps:");
        console.log("  1. Verify contracts on Basescan");
        console.log("  2. Fund vault with test WETH");
        console.log("  3. Test deposit/withdraw flows");
        console.log("  4. Update frontend config with addresses");
        console.log("");
        console.log("Faucets:");
        console.log(
            "  Base Sepolia ETH: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet"
        );
        console.log(
            "  Wrap ETH to WETH: cast send",
            deployment.weth,
            '"deposit()" --value 1ether'
        );
        console.log("");
        console.log(
            "================================================================================"
        );
    }

    function _saveDeploymentConfig(
        BaseSepoliaDeployment memory deployment
    ) private {
        string memory json = string(
            abi.encodePacked(
                "{\n",
                '  "network": "base-sepolia",\n',
                '  "chainId": 84532,\n',
                '  "contracts": {\n',
                '    "aclManager": "',
                vm.toString(deployment.acl),
                '",\n',
                '    "protocolCore": "',
                vm.toString(deployment.core),
                '",\n',
                '    "payoutRouter": "',
                vm.toString(deployment.router),
                '",\n',
                '    "strategyRegistry": "',
                vm.toString(deployment.strategyRegistry),
                '",\n',
                '    "campaignRegistry": "',
                vm.toString(deployment.campaignRegistry),
                '",\n',
                '    "vaultFactory": "',
                vm.toString(deployment.vaultFactory),
                '",\n',
                '    "wethVault": "',
                vm.toString(deployment.wethVault),
                '",\n',
                '    "aaveAdapter": "',
                vm.toString(deployment.aaveAdapter),
                '",\n',
                '    "campaignVault": "',
                vm.toString(deployment.campaignVault),
                '"\n',
                "  },\n",
                '  "assets": {\n',
                '    "weth": "',
                vm.toString(deployment.weth),
                '",\n',
                '    "aavePool": "',
                vm.toString(deployment.aavePool),
                '"\n',
                "  },\n",
                '  "identifiers": {\n',
                '    "strategyId": "',
                vm.toString(deployment.strategyId),
                '",\n',
                '    "campaignId": "',
                vm.toString(deployment.campaignId),
                '",\n',
                '    "vaultId": "',
                vm.toString(deployment.vaultId),
                '"\n',
                "  }\n",
                "}\n"
            )
        );

        console.log("\n--- Deployment Config (copy to frontend) ---");
        console.log(json);

        // Note: File write is disabled during broadcast for security
        // Copy the JSON output above to: /home/give-protocol-v0/backend/deployments/base-sepolia.json
        console.log("\nManually save config to: deployments/base-sepolia.json");
    }
}
