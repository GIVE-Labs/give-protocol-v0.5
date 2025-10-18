// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";
import {MockYieldAdapter} from "../src/adapters/MockYieldAdapter.sol";
import {IYieldAdapter} from "../src/interfaces/IYieldAdapter.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {CampaignVaultFactory} from "../src/vault/CampaignVaultFactory.sol";
import {VaultDeploymentLib} from "../src/vault/VaultDeploymentLib.sol";
import {ManagerDeploymentLib} from "../src/vault/ManagerDeploymentLib.sol";
import {CampaignVault} from "../src/vault/CampaignVault.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployETHVault is Script {
    struct ETHVaultDeployment {
        address roleManager;
        address strategyRegistry;
        address campaignRegistry;
        address payoutRouter;
        address vaultFactory;
        address adapter;
        address campaignVault;
        address strategyManager;
        uint64 strategyId;
        uint64 campaignId;
        address weth;
    }

    function run() external returns (ETHVaultDeployment memory deployment) {
        HelperConfig helperConfig = new HelperConfig();
        (,, address weth,,, address aavePool, uint256 deployerKey) = helperConfig.getActiveNetworkConfig();

        address admin = vm.envOr("ADMIN_ADDRESS", deployerKey == 0 ? msg.sender : vm.addr(deployerKey));
        address curator = vm.envOr("CURATOR_ADDRESS", admin);
        address payoutAddress = vm.envOr("PAYOUT_ADDRESS", admin);
        address protocolTreasury = vm.envOr("PROTOCOL_TREASURY", admin);

        string memory vaultName = vm.envOr("ETH_VAULT_NAME", string("Campaign Vault WETH"));
        string memory vaultSymbol = vm.envOr("ETH_VAULT_SYMBOL", string("cvWETH"));
        string memory strategyMetadata = vm.envOr("ETH_STRATEGY_METADATA_URI", string("ipfs://strategy/aave-weth"));
        string memory campaignMetadata = vm.envOr("ETH_CAMPAIGN_METADATA_URI", string("ipfs://campaign/eth-default"));

        uint256 cashBufferBps = vm.envOr("CASH_BUFFER_BPS", uint256(100));
        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(50));
        uint256 maxLossBps = vm.envOr("MAX_LOSS_BPS", uint256(50));
        uint256 strategyMaxTvl = vm.envOr("STRATEGY_MAX_TVL", type(uint256).max);
        uint256 campaignStake = vm.envOr("CAMPAIGN_STAKE_WEI", uint256(0));

        uint256 riskTierRaw = vm.envOr("STRATEGY_RISK_TIER", uint256(uint8(RegistryTypes.RiskTier.Moderate)));
        require(riskTierRaw <= uint256(uint8(RegistryTypes.RiskTier.Experimental)), "invalid risk tier");
        RegistryTypes.RiskTier riskTier = RegistryTypes.RiskTier(uint8(riskTierRaw));

        uint256 defaultLockRaw = vm.envOr("CAMPAIGN_DEFAULT_LOCK", uint256(uint8(RegistryTypes.LockProfile.Days90)));
        require(defaultLockRaw <= uint256(uint8(RegistryTypes.LockProfile.Days360)), "invalid lock");
        RegistryTypes.LockProfile defaultLock = RegistryTypes.LockProfile(uint8(defaultLockRaw));

        uint256 vaultLockRaw = vm.envOr("VAULT_LOCK_PROFILE", uint256(uint8(defaultLock)));
        require(vaultLockRaw <= uint256(uint8(RegistryTypes.LockProfile.Days360)), "invalid vault lock");
        RegistryTypes.LockProfile vaultLock = RegistryTypes.LockProfile(uint8(vaultLockRaw));

        address existingRoleManager = vm.envOr("EXISTING_ROLE_MANAGER", address(0));
        address existingStrategyRegistry = vm.envOr("EXISTING_STRATEGY_REGISTRY", address(0));
        address existingCampaignRegistry = vm.envOr("EXISTING_CAMPAIGN_REGISTRY", address(0));
        address existingPayoutRouter = vm.envOr("EXISTING_PAYOUT_ROUTER", address(0));
        address existingVaultFactory = vm.envOr("EXISTING_VAULT_FACTORY", address(0));

        address deployer;
        if (deployerKey == 0) {
            vm.startBroadcast();
            deployer = msg.sender;
        } else {
            deployer = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        }

        RoleManager roleManager;
        if (existingRoleManager != address(0)) {
            roleManager = RoleManager(existingRoleManager);
            console.log("Using existing RoleManager", existingRoleManager);
        } else {
            roleManager = new RoleManager(deployer);
            if (admin != deployer) {
                roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), admin);
            }
        }

        // Ensure operator accounts possess required roles
        if (!roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), deployer)) {
            roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), deployer);
        }
        if (!roleManager.hasRole(roleManager.ROLE_STRATEGY_ADMIN(), deployer)) {
            roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), deployer);
        }
        if (!roleManager.hasRole(roleManager.ROLE_CAMPAIGN_ADMIN(), deployer)) {
            roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), deployer);
        }
        if (!roleManager.hasRole(roleManager.ROLE_GUARDIAN(), deployer)) {
            roleManager.grantRole(roleManager.ROLE_GUARDIAN(), deployer);
        }
        if (!roleManager.hasRole(roleManager.ROLE_TREASURY(), protocolTreasury)) {
            roleManager.grantRole(roleManager.ROLE_TREASURY(), protocolTreasury);
        }

        if (admin != deployer) {
            if (!roleManager.hasRole(roleManager.ROLE_VAULT_OPS(), admin)) {
                roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
            }
            if (!roleManager.hasRole(roleManager.ROLE_STRATEGY_ADMIN(), admin)) {
                roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
            }
            if (!roleManager.hasRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin)) {
                roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
            }
            if (!roleManager.hasRole(roleManager.ROLE_GUARDIAN(), admin)) {
                roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
            }
        }

        StrategyRegistry strategyRegistry;
        if (existingStrategyRegistry != address(0)) {
            strategyRegistry = StrategyRegistry(existingStrategyRegistry);
            console.log("Using existing StrategyRegistry", existingStrategyRegistry);
        } else {
            strategyRegistry = new StrategyRegistry(address(roleManager));
        }

        CampaignRegistry campaignRegistry;
        if (existingCampaignRegistry != address(0)) {
            campaignRegistry = CampaignRegistry(existingCampaignRegistry);
            console.log("Using existing CampaignRegistry", existingCampaignRegistry);
        } else {
            campaignRegistry = new CampaignRegistry(
                address(roleManager),
                protocolTreasury,
                address(strategyRegistry),
                vm.envOr("CAMPAIGN_MIN_STAKE", uint256(0))
            );
        }

        uint256 requiredStake = campaignRegistry.minimumStake();
        if (campaignStake < requiredStake) {
            campaignStake = requiredStake;
        }

        PayoutRouter payoutRouter;
        if (existingPayoutRouter != address(0)) {
            payoutRouter = PayoutRouter(existingPayoutRouter);
            console.log("Using existing PayoutRouter", existingPayoutRouter);
        } else {
            payoutRouter = new PayoutRouter(address(roleManager), address(campaignRegistry), protocolTreasury);
        }

        CampaignVaultFactory vaultFactory;
        if (existingVaultFactory != address(0)) {
            vaultFactory = CampaignVaultFactory(existingVaultFactory);
            console.log("Using existing CampaignVaultFactory", existingVaultFactory);
        } else {
            // Deploy helper contracts first
            VaultDeploymentLib vaultDeployer = new VaultDeploymentLib();
            ManagerDeploymentLib managerDeployer = new ManagerDeploymentLib();

            vaultFactory = new CampaignVaultFactory(
                address(roleManager),
                address(strategyRegistry),
                address(campaignRegistry),
                address(payoutRouter),
                address(vaultDeployer),
                address(managerDeployer)
            );
            roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(vaultFactory));
            roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(vaultFactory));
            roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(vaultFactory));
        }

        uint256 predictedNonce = vm.getNonce(address(vaultFactory));
        address predictedVault = vm.computeCreateAddress(address(vaultFactory), predictedNonce);

        IYieldAdapter adapter;
        if (block.chainid == 31337) {
            adapter = new MockYieldAdapter(address(roleManager), weth, predictedVault);
            console.log("Using MockYieldAdapter for local testing");
        } else {
            adapter = new AaveAdapter(address(roleManager), weth, predictedVault, aavePool);
            console.log("Using AaveAdapter for live network");
        }

        uint64 strategyId =
            strategyRegistry.createStrategy(weth, address(adapter), riskTier, strategyMetadata, strategyMaxTvl);

        uint64 campaignId =
            campaignRegistry.submitCampaign{value: campaignStake}(campaignMetadata, curator, payoutAddress, defaultLock);

        campaignRegistry.approveCampaign(campaignId);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        CampaignVaultFactory.Deployment memory campaignDeployment =
            vaultFactory.deployCampaignVault(campaignId, strategyId, vaultLock, vaultName, vaultSymbol, 0.001 ether); // 0.001 ETH minimum
        require(campaignDeployment.vault == predictedVault, "vault address mismatch");

        StrategyManager manager = StrategyManager(campaignDeployment.strategyManager);
        manager.updateVaultParameters(cashBufferBps, slippageBps, maxLossBps);

        CampaignVault(payable(campaignDeployment.vault)).setWrappedNative(weth);

        vm.stopBroadcast();

        console.log("RoleManager:", address(roleManager));
        console.log("StrategyRegistry:", address(strategyRegistry));
        console.log("CampaignRegistry:", address(campaignRegistry));
        console.log("PayoutRouter:", address(payoutRouter));
        console.log("CampaignVaultFactory:", address(vaultFactory));
        console.log("WETH Adapter:", address(adapter));
        console.log("Strategy ID:", strategyId);
        console.log("Campaign ID:", campaignId);
        console.log("Campaign Vault:", campaignDeployment.vault);
        console.log("Strategy Manager:", campaignDeployment.strategyManager);

        deployment = ETHVaultDeployment({
            roleManager: address(roleManager),
            strategyRegistry: address(strategyRegistry),
            campaignRegistry: address(campaignRegistry),
            payoutRouter: address(payoutRouter),
            vaultFactory: address(vaultFactory),
            adapter: address(adapter),
            campaignVault: campaignDeployment.vault,
            strategyManager: campaignDeployment.strategyManager,
            strategyId: strategyId,
            campaignId: campaignId,
            weth: weth
        });
    }

    receive() external payable {}
}
