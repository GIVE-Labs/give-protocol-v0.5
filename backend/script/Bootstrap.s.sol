// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../src/governance/ACLManager.sol";
import "../src/core/GiveProtocolCore.sol";
import "../src/payout/PayoutRouter.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/vault/CampaignVault4626.sol";
import "../src/adapters/MockYieldAdapter.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/factory/CampaignVaultFactory.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/AdapterModule.sol";
import "../src/modules/DonationModule.sol";
import "../src/modules/RiskModule.sol";
import "../src/modules/EmergencyModule.sol";
import "../src/modules/SyntheticModule.sol";
import "../src/storage/StorageLib.sol";
import "../src/types/GiveTypes.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "./HelperConfig.s.sol";

/// @title Bootstrap
/// @notice Deterministic bootstrap script wiring the GIVE Protocol stack
contract Bootstrap is Script {
    error AlreadyBootstrapped();

    struct BootstrapConfig {
        address admin;
        address upgrader;
        address bootstrapper;
        address emergencyCouncil;
        address feeRecipient;
        address protocolTreasury;
        address asset;
        string vaultName;
        string vaultSymbol;
        uint16 cashBufferBps;
        uint16 slippageBps;
        uint16 maxLossBps;
        uint16 donationFeeBps;
        uint16 riskLtvBps;
        uint16 riskLiquidationThresholdBps;
        uint16 riskLiquidationPenaltyBps;
        uint16 riskBorrowCapBps;
        uint16 riskDepositCapBps;
        uint256 riskMaxDeposit;
        uint256 riskMaxBorrow;
        uint256 deployerKey;
        bool deployMockAsset;
        bool useMockAdapter;
        bool broadcast;
        bool allowRedeploy;
    }

    struct Deployment {
        address deployer;
        address admin;
        address asset;
        address acl;
        address core;
        address router;
        address vault;
        address adapter;
        address strategyRegistry;
        address campaignRegistry;
        address vaultFactory;
        address campaignVault;
        bytes32 vaultId;
        bytes32 adapterId;
        bytes32 riskId;
        bytes32 strategyId;
        bytes32 campaignId;
        bytes32 campaignVaultId;
    }

    address internal constant SENTINEL_ADDRESS =
        address(uint160(uint256(keccak256("give.bootstrap.sentinel"))));
    bytes32 internal constant SENTINEL_SLOT =
        keccak256("give.bootstrap.completed");

    /// @notice Main entry point when called via forge script
    function run() public returns (Deployment memory deployment) {
        BootstrapConfig memory cfg = loadConfig();
        cfg.broadcast = true;
        return execute(cfg);
    }

    /// @notice Allows dry-run and testing without broadcasting transactions.
    function execute(
        BootstrapConfig memory cfg
    ) public returns (Deployment memory deployment) {
        // Ensure we only bootstrap once per chain unless storage is reset
        if (
            !cfg.allowRedeploy &&
            vm.load(SENTINEL_ADDRESS, SENTINEL_SLOT) != bytes32(0)
        ) {
            revert AlreadyBootstrapped();
        }

        address deployer = cfg.admin;
        if (cfg.deployerKey != 0) {
            deployer = vm.addr(cfg.deployerKey);
        }

        bool startedPrank = false;
        uint256 chainId = block.chainid;
        bool isLocalChain = (chainId == 31337 || chainId == 1337); // Anvil/Hardhat

        // When broadcasting (local or testnet), use vm.startBroadcast
        // When not broadcasting (test mode), use vm.startPrank
        if (cfg.broadcast) {
            // If using --private-key from command line, don't pass any parameter
            // If using deployerKey from config, pass it to startBroadcast
            if (cfg.deployerKey != 0) {
                vm.startBroadcast(cfg.deployerKey);
            } else {
                vm.startBroadcast(); // No parameter = use --private-key from CLI
            }
        } else {
            vm.startPrank(deployer);
            startedPrank = true;
        }

        deployment.deployer = deployer;
        deployment.admin = cfg.admin;

        IERC20 assetToken = _deployAsset(cfg, deployer);
        cfg.asset = address(assetToken);
        deployment.asset = cfg.asset;

        (ACLManager acl, GiveProtocolCore core) = _deployGovernance(cfg);
        deployment.acl = address(acl);
        deployment.core = address(core);

        _markBootstrapper(cfg);

        (
            StrategyRegistry strategyRegistry,
            CampaignRegistry campaignRegistry
        ) = _deployCampaignInfra(cfg, acl);
        deployment.strategyRegistry = address(strategyRegistry);
        deployment.campaignRegistry = address(campaignRegistry);

        PayoutRouter router = _deployPayoutRouter(cfg, acl, campaignRegistry);
        deployment.router = address(router);

        CampaignVaultFactory factory = _deployCampaignVaultFactory(
            cfg,
            acl,
            campaignRegistry,
            strategyRegistry,
            router
        );
        deployment.vaultFactory = address(factory);

        GiveVault4626 vault = _deployVault(cfg, acl, router, cfg.asset);
        deployment.vault = address(vault);
        deployment.vaultId = vault.vaultId();

        IYieldAdapter adapter = _deployAdapter(cfg, acl, vault, cfg.asset);
        deployment.adapter = address(adapter);
        deployment.adapterId = keccak256(
            abi.encodePacked("adapter", deployment.adapter)
        );

        _wireRoles(
            cfg,
            acl,
            core,
            router,
            vault,
            strategyRegistry,
            campaignRegistry,
            factory
        );

        deployment.riskId = keccak256(abi.encodePacked("risk.primary"));

        deployment = _configureProtocol(
            cfg,
            core,
            vault,
            adapter,
            router,
            strategyRegistry,
            campaignRegistry,
            factory,
            deployment
        );

        // Only stop broadcast if we started it (local chains only)
        if (cfg.broadcast) {
            vm.stopBroadcast();
        } else if (startedPrank) {
            vm.stopPrank();
        }

        _logDeployment(deployment);
        vm.store(SENTINEL_ADDRESS, SENTINEL_SLOT, bytes32(uint256(1)));

        return deployment;
    }

    /// @notice Exposes default config for tests.
    function loadLocalConfig() external returns (BootstrapConfig memory) {
        return _localConfig();
    }

    function _deployAsset(
        BootstrapConfig memory cfg,
        address deployer
    ) private returns (IERC20) {
        if (!cfg.deployMockAsset) {
            return IERC20(cfg.asset);
        }

        ERC20Mock mock = new ERC20Mock();
        // Mint generous supply to admin and deployer for local testing.
        mock.mint(cfg.admin, 10_000_000e18);
        if (cfg.admin != deployer) {
            mock.mint(deployer, 1_000_000e18);
        }

        return IERC20(address(mock));
    }

    function _deployGovernance(
        BootstrapConfig memory cfg
    ) private returns (ACLManager acl, GiveProtocolCore core) {
        ACLManager aclImpl = new ACLManager();
        ERC1967Proxy aclProxy = new ERC1967Proxy(
            address(aclImpl),
            abi.encodeCall(ACLManager.initialize, (cfg.admin, cfg.upgrader))
        );
        acl = ACLManager(address(aclProxy));

        GiveProtocolCore coreImpl = new GiveProtocolCore();
        ERC1967Proxy coreProxy = new ERC1967Proxy(
            address(coreImpl),
            abi.encodeCall(GiveProtocolCore.initialize, (address(acl)))
        );
        core = GiveProtocolCore(address(coreProxy));
    }

    function _deployVault(
        BootstrapConfig memory cfg,
        ACLManager acl,
        PayoutRouter router,
        address assetAddr
    ) private returns (GiveVault4626 vault) {
        // For testnet deployments, Bootstrap contract deploys but admin should be cfg.admin
        // Vault constructor will grant roles to cfg.admin
        vault = new GiveVault4626(
            IERC20(assetAddr),
            cfg.vaultName,
            cfg.vaultSymbol,
            cfg.admin
        );

        // Vault needs to know about the ACL manager
        vault.setACLManager(address(acl));

        // Donation router should recognise the vault after configuration
        vault.setDonationRouter(address(router));

        return vault;
    }

    function _deployAdapter(
        BootstrapConfig memory cfg,
        ACLManager acl,
        GiveVault4626 vault,
        address asset
    ) private returns (IYieldAdapter adapter) {
        // Placeholder until production adapters are wired
        adapter = new MockYieldAdapter(asset, address(vault), cfg.admin);

        MockYieldAdapter(address(adapter)).setACLManager(address(acl));

        return adapter;
    }

    function _deployCampaignInfra(
        BootstrapConfig memory,
        ACLManager acl
    )
        private
        returns (
            StrategyRegistry strategyRegistry,
            CampaignRegistry campaignRegistry
        )
    {
        StrategyRegistry strategyImpl = new StrategyRegistry();
        ERC1967Proxy strategyProxy = new ERC1967Proxy(
            address(strategyImpl),
            abi.encodeCall(StrategyRegistry.initialize, (address(acl)))
        );
        strategyRegistry = StrategyRegistry(address(strategyProxy));

        CampaignRegistry campaignImpl = new CampaignRegistry();
        ERC1967Proxy campaignProxy = new ERC1967Proxy(
            address(campaignImpl),
            abi.encodeCall(
                CampaignRegistry.initialize,
                (address(acl), address(strategyRegistry))
            )
        );
        campaignRegistry = CampaignRegistry(address(campaignProxy));
    }

    function _deployPayoutRouter(
        BootstrapConfig memory cfg,
        ACLManager acl,
        CampaignRegistry campaignRegistry
    ) private returns (PayoutRouter router) {
        PayoutRouter routerImpl = new PayoutRouter();
        ERC1967Proxy routerProxy = new ERC1967Proxy(
            address(routerImpl),
            abi.encodeCall(
                PayoutRouter.initialize,
                (
                    address(acl),
                    address(campaignRegistry),
                    cfg.feeRecipient,
                    cfg.protocolTreasury,
                    cfg.donationFeeBps
                )
            )
        );
        router = PayoutRouter(payable(address(routerProxy)));
    }

    function _deployCampaignVaultFactory(
        BootstrapConfig memory cfg,
        ACLManager acl,
        CampaignRegistry campaignRegistry,
        StrategyRegistry strategyRegistry,
        PayoutRouter router
    ) private returns (CampaignVaultFactory factory) {
        // Deploy vault implementation (logic contract for EIP-1167 clones)
        CampaignVault4626 vaultImpl = new CampaignVault4626(
            IERC20(address(0)), // Dummy asset
            "", // Dummy name
            "", // Dummy symbol
            address(1) // Dummy admin (non-zero to prevent initialization)
        );

        CampaignVaultFactory factoryImpl = new CampaignVaultFactory();
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(
                CampaignVaultFactory.initialize,
                (
                    address(acl),
                    address(campaignRegistry),
                    address(strategyRegistry),
                    address(router),
                    address(vaultImpl)
                )
            )
        );
        factory = CampaignVaultFactory(address(factoryProxy));
    }

    function _wireRoles(
        BootstrapConfig memory cfg,
        ACLManager acl,
        GiveProtocolCore core,
        PayoutRouter router,
        GiveVault4626 vault,
        StrategyRegistry /*strategyRegistry*/,
        CampaignRegistry /*campaignRegistry*/,
        CampaignVaultFactory factory
    ) private {
        address admin = cfg.admin;

        acl.createRole(VaultModule.MANAGER_ROLE, admin);
        acl.createRole(AdapterModule.MANAGER_ROLE, admin);
        acl.createRole(DonationModule.MANAGER_ROLE, admin);
        acl.createRole(RiskModule.MANAGER_ROLE, admin);
        acl.createRole(SyntheticModule.MANAGER_ROLE, admin);
        acl.createRole(EmergencyModule.MANAGER_ROLE, admin);

        bytes32 emergencyRole = keccak256("EMERGENCY_ROLE");
        acl.createRole(emergencyRole, admin);

        acl.grantRole(VaultModule.MANAGER_ROLE, admin);
        acl.grantRole(VaultModule.MANAGER_ROLE, address(core));
        acl.grantRole(AdapterModule.MANAGER_ROLE, admin);
        acl.grantRole(DonationModule.MANAGER_ROLE, admin);
        acl.grantRole(RiskModule.MANAGER_ROLE, admin);
        acl.grantRole(RiskModule.MANAGER_ROLE, address(core));
        acl.grantRole(emergencyRole, cfg.emergencyCouncil);

        acl.grantRole(acl.campaignAdminRole(), admin);
        acl.grantRole(acl.campaignCreatorRole(), admin);
        acl.grantRole(acl.campaignCuratorRole(), admin);
        acl.grantRole(acl.checkpointCouncilRole(), admin);
        acl.grantRole(acl.strategyAdminRole(), admin);

        // Grant deployer script temporary roles for seeding infrastructure
        // During broadcast, the script contract is the msg.sender for internal calls
        acl.grantRole(acl.strategyAdminRole(), address(this));
        acl.grantRole(acl.campaignCreatorRole(), address(this));
        acl.grantRole(acl.campaignCuratorRole(), address(this));

        acl.grantRole(acl.campaignAdminRole(), address(factory));
        acl.grantRole(acl.strategyAdminRole(), address(factory));

        // Router role wiring
        acl.createRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), address(factory));
        acl.createRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(router.FEE_MANAGER_ROLE(), admin);

        // Vault access for core + council
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(core));
        vault.grantRole(vault.PAUSER_ROLE(), cfg.emergencyCouncil);
        vault.grantRole(vault.PAUSER_ROLE(), address(core));
    }

    function _configureProtocol(
        BootstrapConfig memory cfg,
        GiveProtocolCore core,
        GiveVault4626 vault,
        IYieldAdapter adapter,
        PayoutRouter router,
        StrategyRegistry strategyRegistry,
        CampaignRegistry campaignRegistry,
        CampaignVaultFactory factory,
        Deployment memory deployment
    ) private returns (Deployment memory) {
        bytes32 adapterId = deployment.adapterId;
        bytes32 riskId = deployment.riskId;

        core.configureVault(
            deployment.vaultId,
            VaultModule.VaultConfigInput({
                id: deployment.vaultId,
                proxy: address(vault),
                implementation: address(vault),
                asset: address(vault.asset()),
                adapterId: adapterId,
                donationModuleId: bytes32(0),
                riskId: riskId,
                cashBufferBps: cfg.cashBufferBps,
                slippageBps: cfg.slippageBps,
                maxLossBps: cfg.maxLossBps
            })
        );

        core.configureAdapter(
            adapterId,
            AdapterModule.AdapterConfigInput({
                id: adapterId,
                proxy: address(adapter),
                implementation: address(adapter),
                asset: address(vault.asset()),
                vault: address(vault),
                kind: GiveTypes.AdapterKind.CompoundingValue,
                metadataHash: bytes32(0)
            })
        );

        core.configureRisk(
            riskId,
            RiskModule.RiskConfigInput({
                id: riskId,
                ltvBps: cfg.riskLtvBps,
                liquidationThresholdBps: cfg.riskLiquidationThresholdBps,
                liquidationPenaltyBps: cfg.riskLiquidationPenaltyBps,
                borrowCapBps: cfg.riskBorrowCapBps,
                depositCapBps: cfg.riskDepositCapBps,
                dataHash: bytes32(0),
                maxDeposit: cfg.riskMaxDeposit,
                maxBorrow: cfg.riskMaxBorrow
            })
        );

        core.assignVaultRisk(deployment.vaultId, riskId);

        vault.setActiveAdapter(adapter);

        (bytes32 strategyId, bytes32 campaignId) = _seedCampaignInfrastructure(
            cfg,
            strategyRegistry,
            campaignRegistry,
            adapter
        );

        deployment.strategyId = strategyId;
        deployment.campaignId = campaignId;

        StorageLib.setBytes32(keccak256("strategy.default.id"), strategyId);
        StorageLib.setBytes32(keccak256("campaign.default.id"), campaignId);

        deployment = _deploySampleCampaignVault(
            cfg,
            factory,
            campaignRegistry,
            router,
            deployment
        );

        router.registerCampaignVault(address(vault), campaignId);
        router.setAuthorizedCaller(address(vault), true);

        return deployment;
    }
    function _seedCampaignInfrastructure(
        BootstrapConfig memory cfg,
        StrategyRegistry strategyRegistry,
        CampaignRegistry campaignRegistry,
        IYieldAdapter adapter
    ) private returns (bytes32 strategyId, bytes32 campaignId) {
        strategyId = keccak256("strategy.primary");
        campaignId = keccak256("campaign.primary");

        GiveTypes.StrategyConfig storage existingStrategy = StorageLib.strategy(
            strategyId
        );
        if (!existingStrategy.exists) {
            StrategyRegistry.StrategyInput
                memory strategyInput = StrategyRegistry.StrategyInput({
                    id: strategyId,
                    adapter: address(adapter),
                    riskTier: bytes32("tier.core"),
                    maxTvl: cfg.riskMaxDeposit,
                    metadataHash: keccak256("strategy.primary.metadata")
                });

            strategyRegistry.registerStrategy(strategyInput);
        }

        GiveTypes.CampaignConfig storage existingCampaign = StorageLib.campaign(
            campaignId
        );
        if (!existingCampaign.exists) {
            CampaignRegistry.CampaignInput
                memory campaignInput = CampaignRegistry.CampaignInput({
                    id: campaignId,
                    payoutRecipient: cfg.protocolTreasury,
                    strategyId: strategyId,
                    metadataHash: keccak256("campaign.primary.metadata"),
                    targetStake: cfg.riskMaxDeposit,
                    minStake: cfg.riskMaxDeposit / 10,
                    fundraisingStart: uint64(block.timestamp),
                    fundraisingEnd: uint64(block.timestamp + 30 days)
                });

            campaignRegistry.submitCampaign(campaignInput);
            campaignRegistry.approveCampaign(campaignId, cfg.bootstrapper);
        }
    }

    function _deploySampleCampaignVault(
        BootstrapConfig memory cfg,
        CampaignVaultFactory factory,
        CampaignRegistry campaignRegistry,
        PayoutRouter router,
        Deployment memory deployment
    ) private returns (Deployment memory) {
        bytes32 lockProfile = keccak256("lock.default");

        CampaignVaultFactory.DeployParams memory params = CampaignVaultFactory
            .DeployParams({
                campaignId: deployment.campaignId,
                strategyId: deployment.strategyId,
                lockProfile: lockProfile,
                asset: cfg.asset,
                admin: cfg.admin,
                name: string(abi.encodePacked("Campaign ", cfg.vaultName)),
                symbol: string(abi.encodePacked("c", cfg.vaultSymbol))
            });

        address campaignVault = factory.deployCampaignVault(params);
        deployment.campaignVault = campaignVault;
        deployment.campaignVaultId = CampaignVault4626(payable(campaignVault))
            .vaultId();

        CampaignVault4626(payable(campaignVault)).setACLManager(deployment.acl);
        CampaignVault4626(payable(campaignVault)).setDonationRouter(
            address(router)
        );
        router.registerCampaignVault(campaignVault, deployment.campaignId);
        router.setAuthorizedCaller(campaignVault, true);
        campaignRegistry.setCampaignVault(
            deployment.campaignId,
            campaignVault,
            lockProfile
        );

        StorageLib.setAddress(
            keccak256("campaign.vault.default"),
            campaignVault
        );
        StorageLib.setBytes32(keccak256("campaign.lock.default"), lockProfile);

        return deployment;
    }

    function _logDeployment(Deployment memory deployment) private view {
        console.log("\n=== GIVE Protocol Bootstrap ===");
        console.log("Deployer:", deployment.deployer);
        console.log("Admin:", deployment.admin);
        console.log("ACL Manager:", deployment.acl);
        console.log("GiveProtocolCore:", deployment.core);
        console.log("Payout Router:", deployment.router);
        console.log("Strategy Registry:", deployment.strategyRegistry);
        console.log("Campaign Registry:", deployment.campaignRegistry);
        console.log("Campaign Vault Factory:", deployment.vaultFactory);
        console.log("Campaign Vault:", deployment.campaignVault);
        console.log("Vault:", deployment.vault);
        console.log("Adapter:", deployment.adapter);
        console.log("Asset:", deployment.asset);
        console.log("Vault ID:", vm.toString(deployment.vaultId));
        console.log("Adapter ID:", vm.toString(deployment.adapterId));
        console.log("Risk ID:", vm.toString(deployment.riskId));
        console.log("Strategy ID:", vm.toString(deployment.strategyId));
        console.log("Campaign ID:", vm.toString(deployment.campaignId));
        console.log(
            "Campaign Vault ID:",
            vm.toString(deployment.campaignVaultId)
        );
    }

    /// @notice Loads configuration from environment variables and network config
    /// @dev Can be called externally to get config before calling execute()
    /// @return cfg The loaded bootstrap configuration
    function loadConfig() public returns (BootstrapConfig memory cfg) {
        bool isLocal = block.chainid == 31337;
        bool isBaseSepolia = block.chainid == 84532;

        HelperConfig helper = new HelperConfig();
        (, , address weth, , address usdc, , uint256 helperKey) = helper
            .getActiveNetworkConfig();

        uint256 deployerKey = vm.envOr("DEPLOYER_KEY", helperKey);

        // Use tx.origin if deployerKey is 0 (when using --account or --private-key flag)
        // tx.origin gives us the actual EOA, not the script contract address
        address admin = deployerKey == 0
            ? tx.origin
            : vm.envOr("ADMIN_ADDRESS", vm.addr(deployerKey));
        address upgrader = vm.envOr("UPGRADER_ADDRESS", admin);
        address bootstrapper = vm.envOr("BOOTSTRAPPER_ADDRESS", admin);
        address emergencyCouncil = vm.envOr("EMERGENCY_COUNCIL", admin);

        // For Base Sepolia, default to WETH if no asset specified
        address asset;
        if (isBaseSepolia) {
            asset = vm.envOr("VAULT_ASSET", weth);
        } else {
            asset = vm.envOr("VAULT_ASSET", isLocal ? address(0) : usdc);
        }
        bool deployMockAsset = isLocal || asset == address(0);

        // Determine vault name/symbol based on asset
        string memory defaultName;
        string memory defaultSymbol;
        if (isBaseSepolia && asset == weth) {
            defaultName = "GIVE WETH Vault";
            defaultSymbol = "gvWETH";
        } else if (isLocal) {
            defaultName = "Mock GIVE Vault";
            defaultSymbol = "gvMOCK";
        } else {
            defaultName = "GIVE Vault";
            defaultSymbol = "gvASSET";
        }

        cfg = BootstrapConfig({
            admin: admin,
            upgrader: upgrader,
            bootstrapper: bootstrapper,
            emergencyCouncil: emergencyCouncil,
            feeRecipient: vm.envOr("FEE_RECIPIENT_ADDRESS", admin),
            protocolTreasury: vm.envOr("PROTOCOL_TREASURY", admin),
            asset: asset,
            vaultName: vm.envOr("VAULT_NAME", defaultName),
            vaultSymbol: vm.envOr("VAULT_SYMBOL", defaultSymbol),
            cashBufferBps: uint16(vm.envOr("CASH_BUFFER_BPS", uint256(100))),
            slippageBps: uint16(vm.envOr("SLIPPAGE_BPS", uint256(50))),
            maxLossBps: uint16(vm.envOr("MAX_LOSS_BPS", uint256(50))),
            donationFeeBps: uint16(vm.envOr("DONATION_FEE_BPS", uint256(250))),
            riskLtvBps: uint16(vm.envOr("RISK_LTV_BPS", uint256(7000))),
            riskLiquidationThresholdBps: uint16(
                vm.envOr("RISK_LIQ_THRESHOLD_BPS", uint256(8000))
            ),
            riskLiquidationPenaltyBps: uint16(
                vm.envOr("RISK_LIQ_PENALTY_BPS", uint256(300))
            ),
            riskBorrowCapBps: uint16(
                vm.envOr("RISK_BORROW_CAP_BPS", uint256(4000))
            ),
            riskDepositCapBps: uint16(
                vm.envOr("RISK_DEPOSIT_CAP_BPS", uint256(9500))
            ),
            riskMaxDeposit: vm.envOr(
                "RISK_MAX_DEPOSIT",
                uint256(10_000_000e18)
            ),
            riskMaxBorrow: vm.envOr("RISK_MAX_BORROW", uint256(6_000_000e18)),
            deployerKey: deployerKey,
            deployMockAsset: deployMockAsset,
            useMockAdapter: vm.envOr(
                "USE_MOCK_ADAPTER",
                uint256(deployMockAsset ? 1 : 0)
            ) == 1,
            broadcast: false,
            allowRedeploy: vm.envOr("ALLOW_REDEPLOY", uint256(0)) == 1
        });
    }

    function _localConfig() private returns (BootstrapConfig memory cfg) {
        HelperConfig helper = new HelperConfig();
        (, , , , , , uint256 helperKey) = helper.getActiveNetworkConfig();

        cfg = BootstrapConfig({
            admin: vm.addr(helperKey),
            upgrader: vm.addr(helperKey),
            bootstrapper: vm.addr(helperKey),
            emergencyCouncil: vm.addr(helperKey),
            feeRecipient: vm.addr(helperKey),
            protocolTreasury: vm.addr(helperKey),
            asset: address(0),
            vaultName: "Mock GIVE Vault",
            vaultSymbol: "gvMOCK",
            cashBufferBps: 100,
            slippageBps: 50,
            maxLossBps: 50,
            donationFeeBps: 250,
            riskLtvBps: 7000,
            riskLiquidationThresholdBps: 8000,
            riskLiquidationPenaltyBps: 300,
            riskBorrowCapBps: 4000,
            riskDepositCapBps: 9500,
            riskMaxDeposit: 10_000_000e18,
            riskMaxBorrow: 6_000_000e18,
            deployerKey: helperKey,
            deployMockAsset: true,
            useMockAdapter: true,
            broadcast: false,
            allowRedeploy: false
        });
    }

    function _markBootstrapper(BootstrapConfig memory cfg) private {
        GiveTypes.SystemConfig storage sys = StorageLib.system();
        sys.bootstrapper = cfg.bootstrapper;
        sys.upgrader = cfg.upgrader;
    }
}
