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
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {PayoutRouter} from "../src/payout/PayoutRouter.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract Deploy is Script {
    struct Deployed {
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
    }

    function run() external returns (Deployed memory out) {
        HelperConfig helperConfig = new HelperConfig();
        (,,,, address usdc, address aavePool, uint256 deployerKey) = helperConfig.getActiveNetworkConfig();

        address admin = vm.envOr("ADMIN_ADDRESS", deployerKey == 0 ? msg.sender : vm.addr(deployerKey));
        address curator = vm.envOr("CURATOR_ADDRESS", admin);
        address payoutAddress = vm.envOr("PAYOUT_ADDRESS", admin);
        address protocolTreasury = vm.envOr("PROTOCOL_TREASURY", admin);
        address assetAddress = vm.envOr("ASSET_ADDRESS", usdc);

        string memory vaultName = vm.envOr("VAULT_NAME", string("Campaign Vault USDC"));
        string memory vaultSymbol = vm.envOr("VAULT_SYMBOL", string("cvUSDC"));
        string memory strategyMetadata = vm.envOr("STRATEGY_METADATA_URI", string("ipfs://strategy/aave-usdc"));
        string memory campaignMetadata = vm.envOr("CAMPAIGN_METADATA_URI", string("ipfs://campaign/default"));

        uint256 cashBufferBps = vm.envOr("CASH_BUFFER_BPS", uint256(100));
        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(50));
        uint256 maxLossBps = vm.envOr("MAX_LOSS_BPS", uint256(50));
        uint256 strategyMaxTvl = vm.envOr("STRATEGY_MAX_TVL", type(uint256).max);
        uint256 campaignStake = vm.envOr("CAMPAIGN_STAKE_WEI", uint256(0));
        uint256 minStake = vm.envOr("CAMPAIGN_MIN_STAKE", uint256(0));

        uint256 riskTierRaw = vm.envOr("STRATEGY_RISK_TIER", uint256(uint8(RegistryTypes.RiskTier.Conservative)));
        require(riskTierRaw <= uint256(uint8(RegistryTypes.RiskTier.Experimental)), "invalid risk tier");
        RegistryTypes.RiskTier riskTier = RegistryTypes.RiskTier(uint8(riskTierRaw));

        uint256 campaignLockRaw = vm.envOr("CAMPAIGN_DEFAULT_LOCK", uint256(uint8(RegistryTypes.LockProfile.Days90)));
        require(campaignLockRaw <= uint256(uint8(RegistryTypes.LockProfile.Days360)), "invalid lock");
        RegistryTypes.LockProfile defaultLock = RegistryTypes.LockProfile(uint8(campaignLockRaw));

        uint256 vaultLockRaw = vm.envOr("VAULT_LOCK_PROFILE", uint256(uint8(defaultLock)));
        require(vaultLockRaw <= uint256(uint8(RegistryTypes.LockProfile.Days360)), "invalid vault lock");
        RegistryTypes.LockProfile vaultLock = RegistryTypes.LockProfile(uint8(vaultLockRaw));

        address deployer;
        if (deployerKey == 0) {
            vm.startBroadcast();
            deployer = msg.sender;
        } else {
            deployer = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
        }

        RoleManager roleManager = new RoleManager(deployer);
        if (admin != deployer) {
            roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), admin);
        }
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), deployer);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), deployer);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), deployer);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), protocolTreasury);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), deployer);

        if (admin != deployer) {
            roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
            roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
            roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
            roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        }

        StrategyRegistry strategyRegistry = new StrategyRegistry(address(roleManager));
        CampaignRegistry campaignRegistry =
            new CampaignRegistry(address(roleManager), protocolTreasury, address(strategyRegistry), minStake);
        PayoutRouter payoutRouter = new PayoutRouter(address(roleManager), address(campaignRegistry), protocolTreasury);
        CampaignVaultFactory vaultFactory = new CampaignVaultFactory(
            address(roleManager), address(strategyRegistry), address(campaignRegistry), address(payoutRouter)
        );

        roleManager.grantRole(roleManager.DEFAULT_ADMIN_ROLE(), address(vaultFactory));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), address(vaultFactory));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), address(vaultFactory));

        uint256 predictedNonce = vm.getNonce(address(vaultFactory));
        address predictedVault = vm.computeCreateAddress(address(vaultFactory), predictedNonce);

        IYieldAdapter adapter;
        if (block.chainid == 31337) {
            adapter = new MockYieldAdapter(address(roleManager), assetAddress, predictedVault);
            console.log("Using MockYieldAdapter for local testing");
        } else {
            adapter = new AaveAdapter(address(roleManager), assetAddress, predictedVault, aavePool);
            console.log("Using AaveAdapter for live network");
        }

        uint256 requiredStake = campaignRegistry.minimumStake();
        if (campaignStake < requiredStake) {
            campaignStake = requiredStake;
        }

        uint64 strategyId =
            strategyRegistry.createStrategy(assetAddress, address(adapter), riskTier, strategyMetadata, strategyMaxTvl);

        uint64 campaignId =
            campaignRegistry.submitCampaign{value: campaignStake}(campaignMetadata, curator, payoutAddress, defaultLock);

        campaignRegistry.approveCampaign(campaignId);
        campaignRegistry.attachStrategy(campaignId, strategyId);

        CampaignVaultFactory.Deployment memory deployment =
            vaultFactory.deployCampaignVault(campaignId, strategyId, vaultLock, vaultName, vaultSymbol, 1e6); // 1 USDC minimum
        require(deployment.vault == predictedVault, "vault address mismatch");

        StrategyManager manager = StrategyManager(deployment.strategyManager);
        manager.updateVaultParameters(cashBufferBps, slippageBps, maxLossBps);

        vm.stopBroadcast();

        console.log("RoleManager:", address(roleManager));
        console.log("StrategyRegistry:", address(strategyRegistry));
        console.log("CampaignRegistry:", address(campaignRegistry));
        console.log("PayoutRouter:", address(payoutRouter));
        console.log("CampaignVaultFactory:", address(vaultFactory));
        console.log("Strategy Adapter:", address(adapter));
        console.log("Strategy ID:", strategyId);
        console.log("Campaign ID:", campaignId);
        console.log("Campaign Vault:", deployment.vault);
        console.log("Strategy Manager:", deployment.strategyManager);

        out = Deployed({
            roleManager: address(roleManager),
            strategyRegistry: address(strategyRegistry),
            campaignRegistry: address(campaignRegistry),
            payoutRouter: address(payoutRouter),
            vaultFactory: address(vaultFactory),
            adapter: address(adapter),
            campaignVault: deployment.vault,
            strategyManager: deployment.strategyManager,
            strategyId: strategyId,
            campaignId: campaignId
        });
    }

    receive() external payable {}
}
