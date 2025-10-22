// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../src/governance/ACLManager.sol";
import "../src/core/GiveProtocolCore.sol";
import "../src/donation/DonationRouter.sol";
import "../src/donation/NGORegistry.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/adapters/MockYieldAdapter.sol";
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
        address registry;
        address router;
        address vault;
        address adapter;
        bytes32 vaultId;
        bytes32 adapterId;
        bytes32 donationId;
        bytes32 riskId;
    }

    address internal constant SENTINEL_ADDRESS = address(uint160(uint256(keccak256("give.bootstrap.sentinel"))));
    bytes32 internal constant SENTINEL_SLOT = keccak256("give.bootstrap.completed");

    /// @notice Entry point used by `forge script`
    function run() external returns (Deployment memory deployment) {
        BootstrapConfig memory cfg = _loadConfig();
        cfg.broadcast = true;
        return execute(cfg);
    }

    /// @notice Allows dry-run and testing without broadcasting transactions.
    function execute(BootstrapConfig memory cfg) public returns (Deployment memory deployment) {
        // Ensure we only bootstrap once per chain unless storage is reset
        if (!cfg.allowRedeploy && vm.load(SENTINEL_ADDRESS, SENTINEL_SLOT) != bytes32(0)) {
            revert AlreadyBootstrapped();
        }

        address deployer = cfg.admin;
        if (cfg.deployerKey != 0) {
            deployer = vm.addr(cfg.deployerKey);
        }

        bool startedPrank = false;

        if (cfg.broadcast) {
            if (cfg.deployerKey != 0) {
                vm.startBroadcast(cfg.deployerKey);
            } else {
                vm.startBroadcast(deployer);
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

        (NGORegistry registry, DonationRouter router) = _deployDonation(cfg, acl);
        deployment.registry = address(registry);
        deployment.router = address(router);

        GiveVault4626 vault = _deployVault(cfg, acl, router, cfg.asset);
        deployment.vault = address(vault);
        deployment.vaultId = vault.vaultId();

        IYieldAdapter adapter = _deployAdapter(cfg, acl, vault, cfg.asset);
        deployment.adapter = address(adapter);
        deployment.adapterId = keccak256(abi.encodePacked("adapter", deployment.adapter));

        _wireRoles(cfg, acl, core, registry, router, vault);

        deployment.donationId = keccak256(abi.encodePacked("donation.router"));
        deployment.riskId = keccak256(abi.encodePacked("risk.primary"));

        _configureProtocol(cfg, core, vault, adapter, router, deployment);

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

    function _deployAsset(BootstrapConfig memory cfg, address deployer) private returns (IERC20) {
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

    function _deployGovernance(BootstrapConfig memory cfg)
        private
        returns (ACLManager acl, GiveProtocolCore core)
    {
        ACLManager aclImpl = new ACLManager();
        ERC1967Proxy aclProxy =
            new ERC1967Proxy(address(aclImpl), abi.encodeCall(ACLManager.initialize, (cfg.admin, cfg.upgrader)));
        acl = ACLManager(address(aclProxy));

        GiveProtocolCore coreImpl = new GiveProtocolCore();
        ERC1967Proxy coreProxy =
            new ERC1967Proxy(address(coreImpl), abi.encodeCall(GiveProtocolCore.initialize, (address(acl))));
        core = GiveProtocolCore(address(coreProxy));
    }

    function _deployDonation(BootstrapConfig memory cfg, ACLManager acl)
        private
        returns (NGORegistry registry, DonationRouter router)
    {
        NGORegistry registryImpl = new NGORegistry();
        ERC1967Proxy registryProxy =
            new ERC1967Proxy(address(registryImpl), abi.encodeCall(NGORegistry.initialize, (address(acl))));
        registry = NGORegistry(address(registryProxy));

        DonationRouter routerImpl = new DonationRouter();
        ERC1967Proxy routerProxy = new ERC1967Proxy(
            address(routerImpl),
            abi.encodeCall(
                DonationRouter.initialize,
                (address(acl), address(registry), cfg.feeRecipient, cfg.protocolTreasury, cfg.donationFeeBps)
            )
        );
        router = DonationRouter(payable(address(routerProxy)));
    }

    function _deployVault(
        BootstrapConfig memory cfg,
        ACLManager acl,
        DonationRouter router,
        address assetAddr
    ) private returns (GiveVault4626 vault) {
        vault = new GiveVault4626(IERC20(assetAddr), cfg.vaultName, cfg.vaultSymbol, cfg.admin);

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

    function _wireRoles(
        BootstrapConfig memory cfg,
        ACLManager acl,
        GiveProtocolCore core,
        NGORegistry registry,
        DonationRouter router,
        GiveVault4626 vault
    ) private {
        address admin = cfg.admin;

        acl.createRole(VaultModule.MANAGER_ROLE, admin);
        acl.createRole(AdapterModule.MANAGER_ROLE, admin);
        acl.createRole(DonationModule.MANAGER_ROLE, admin);
        acl.createRole(RiskModule.MANAGER_ROLE, admin);
        acl.createRole(SyntheticModule.MANAGER_ROLE, admin);
        acl.createRole(EmergencyModule.MANAGER_ROLE, admin);
        acl.createRole(registry.NGO_MANAGER_ROLE(), admin);
        acl.createRole(registry.DONATION_RECORDER_ROLE(), admin);

        bytes32 emergencyRole = keccak256("EMERGENCY_ROLE");
        acl.createRole(emergencyRole, admin);

        acl.grantRole(VaultModule.MANAGER_ROLE, admin);
        acl.grantRole(VaultModule.MANAGER_ROLE, address(core));
        acl.grantRole(AdapterModule.MANAGER_ROLE, admin);
        acl.grantRole(DonationModule.MANAGER_ROLE, admin);
        acl.grantRole(RiskModule.MANAGER_ROLE, admin);
        acl.grantRole(RiskModule.MANAGER_ROLE, address(core));
        acl.grantRole(emergencyRole, cfg.emergencyCouncil);
        acl.grantRole(registry.NGO_MANAGER_ROLE(), admin);
        acl.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));

        // Donation router role wiring
        acl.createRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.createRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(router.FEE_MANAGER_ROLE(), admin);

        router.setAuthorizedCaller(address(vault), true);

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
        DonationRouter router,
        Deployment memory deployment
    ) private {
        bytes32 adapterId = deployment.adapterId;
        bytes32 donationId = deployment.donationId;
        bytes32 riskId = deployment.riskId;

        core.configureVault(
            deployment.vaultId,
            VaultModule.VaultConfigInput({
                id: deployment.vaultId,
                proxy: address(vault),
                implementation: address(vault),
                asset: address(vault.asset()),
                adapterId: adapterId,
                donationModuleId: donationId,
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

        core.configureDonation(
            donationId,
            DonationModule.DonationConfigInput({
                id: donationId,
                routerProxy: address(router),
                registryProxy: address(deployment.registry),
                feeRecipient: cfg.feeRecipient,
                feeBps: cfg.donationFeeBps
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
    }

    function _logDeployment(Deployment memory deployment) private view {
        console.log("\n=== GIVE Protocol Bootstrap ===");
        console.log("Deployer:", deployment.deployer);
        console.log("Admin:", deployment.admin);
        console.log("ACL Manager:", deployment.acl);
        console.log("GiveProtocolCore:", deployment.core);
        console.log("NGO Registry:", deployment.registry);
        console.log("Donation Router:", deployment.router);
        console.log("Vault:", deployment.vault);
        console.log("Adapter:", deployment.adapter);
        console.log("Asset:", deployment.asset);
        console.log("Vault ID:", vm.toString(deployment.vaultId));
        console.log("Adapter ID:", vm.toString(deployment.adapterId));
        console.log("Donation ID:", vm.toString(deployment.donationId));
        console.log("Risk ID:", vm.toString(deployment.riskId));
    }

    function _loadConfig() private returns (BootstrapConfig memory cfg) {
        bool isLocal = block.chainid == 31337;

        HelperConfig helper = new HelperConfig();
        (, , , , address usdc,, uint256 helperKey) = helper.getActiveNetworkConfig();

        uint256 deployerKey = vm.envOr("DEPLOYER_KEY", helperKey);
        address admin = vm.envOr("ADMIN_ADDRESS", vm.addr(deployerKey));
        address upgrader = vm.envOr("UPGRADER_ADDRESS", admin);
        address bootstrapper = vm.envOr("BOOTSTRAPPER_ADDRESS", admin);
        address emergencyCouncil = vm.envOr("EMERGENCY_COUNCIL", admin);

        address asset = vm.envOr("VAULT_ASSET", isLocal ? address(0) : usdc);
        bool deployMockAsset = isLocal || asset == address(0);

        cfg = BootstrapConfig({
            admin: admin,
            upgrader: upgrader,
            bootstrapper: bootstrapper,
            emergencyCouncil: emergencyCouncil,
            feeRecipient: vm.envOr("FEE_RECIPIENT_ADDRESS", admin),
            protocolTreasury: vm.envOr("PROTOCOL_TREASURY", admin),
            asset: asset,
            vaultName: vm.envOr("VAULT_NAME", isLocal ? string("Mock GIVE Vault") : string("GIVE Vault")),
            vaultSymbol: vm.envOr("VAULT_SYMBOL", isLocal ? string("gvMOCK") : string("gvASSET")),
            cashBufferBps: uint16(vm.envOr("CASH_BUFFER_BPS", uint256(100))),
            slippageBps: uint16(vm.envOr("SLIPPAGE_BPS", uint256(50))),
            maxLossBps: uint16(vm.envOr("MAX_LOSS_BPS", uint256(50))),
            donationFeeBps: uint16(vm.envOr("DONATION_FEE_BPS", uint256(250))),
            riskLtvBps: uint16(vm.envOr("RISK_LTV_BPS", uint256(7000))),
            riskLiquidationThresholdBps: uint16(vm.envOr("RISK_LIQ_THRESHOLD_BPS", uint256(8000))),
            riskLiquidationPenaltyBps: uint16(vm.envOr("RISK_LIQ_PENALTY_BPS", uint256(300))),
            riskBorrowCapBps: uint16(vm.envOr("RISK_BORROW_CAP_BPS", uint256(4000))),
            riskDepositCapBps: uint16(vm.envOr("RISK_DEPOSIT_CAP_BPS", uint256(9500))),
            riskMaxDeposit: vm.envOr("RISK_MAX_DEPOSIT", uint256(10_000_000e18)),
            riskMaxBorrow: vm.envOr("RISK_MAX_BORROW", uint256(6_000_000e18)),
            deployerKey: deployerKey,
            deployMockAsset: deployMockAsset,
            useMockAdapter: vm.envOr("USE_MOCK_ADAPTER", uint256(deployMockAsset ? 1 : 0)) == 1,
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
