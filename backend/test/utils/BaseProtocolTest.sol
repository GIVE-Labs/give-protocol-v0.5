// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../../script/Bootstrap.s.sol";
import "../../src/governance/ACLManager.sol";
import "../../src/core/GiveProtocolCore.sol";
import "../../src/vault/GiveVault4626.sol";
import "../../src/payout/PayoutRouter.sol";
import "../../src/registry/StrategyRegistry.sol";
import "../../src/registry/CampaignRegistry.sol";
import "../../src/interfaces/IYieldAdapter.sol";

/// @notice Shared Foundry harness that deploys the GIVE Protocol stack once per test.
contract BaseProtocolTest is Test {
    Bootstrap internal bootstrap;
    Bootstrap.Deployment internal deployment;

    ACLManager internal acl;
    GiveProtocolCore internal core;
    GiveVault4626 internal vault;
    PayoutRouter internal router;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    IYieldAdapter internal adapter;
    ERC20Mock internal asset;

    address internal admin;
    address internal emergencyCouncil;
    address internal feeRecipient;
    address internal protocolTreasury;

    address private constant SENTINEL_ADDR = address(uint160(uint256(keccak256("give.bootstrap.sentinel"))));
    bytes32 private constant SENTINEL_SLOT = keccak256("give.bootstrap.completed");

    function setUp() public virtual {
        bootstrap = new Bootstrap();

        admin = makeAddr("admin");
        emergencyCouncil = makeAddr("emergency");
        feeRecipient = makeAddr("feeRecipient");
        protocolTreasury = makeAddr("protocolTreasury");

        // Reset bootstrap sentinel so each test starts from a clean state.
        vm.store(SENTINEL_ADDR, SENTINEL_SLOT, bytes32(0));

        Bootstrap.BootstrapConfig memory cfg = bootstrap.loadLocalConfig();
        cfg.admin = admin;
        cfg.upgrader = admin;
        cfg.bootstrapper = admin;
        cfg.emergencyCouncil = emergencyCouncil;
        cfg.feeRecipient = feeRecipient;
        cfg.protocolTreasury = protocolTreasury;
        cfg.deployerKey = 0;
        cfg.broadcast = false;
        cfg.allowRedeploy = true;
        cfg.deployMockAsset = true;
        cfg.useMockAdapter = true;

        deployment = bootstrap.execute(cfg);

        acl = ACLManager(deployment.acl);
        core = GiveProtocolCore(deployment.core);
        vault = GiveVault4626(payable(deployment.vault));
        router = PayoutRouter(payable(deployment.router));
        strategyRegistry = StrategyRegistry(deployment.strategyRegistry);
        campaignRegistry = CampaignRegistry(deployment.campaignRegistry);
        adapter = IYieldAdapter(deployment.adapter);
        asset = ERC20Mock(deployment.asset);

        _grantRole(router.VAULT_MANAGER_ROLE(), admin);
        _grantRole(router.FEE_MANAGER_ROLE(), admin);
    }

    function _expectUnauthorized(bytes32 role, address caller) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(GiveProtocolCore.Unauthorized.selector, role, caller);
    }

    function _grantRole(bytes32 roleId, address account) internal {
        vm.startPrank(admin);
        acl.grantRole(roleId, account);
        vm.stopPrank();
    }
}
