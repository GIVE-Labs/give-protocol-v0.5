// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../script/Bootstrap.s.sol";
import "../src/governance/ACLManager.sol";
import "../src/core/GiveProtocolCore.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/donation/DonationRouter.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/AdapterModule.sol";
import "../src/modules/RiskModule.sol";
import "../src/types/GiveTypes.sol";

contract BootstrapScriptTest is Test {
    Bootstrap internal bootstrap;
    Bootstrap.BootstrapConfig internal config;

    function setUp() public {
        address sentinelAddr = address(uint160(uint256(keccak256("give.bootstrap.sentinel"))));
        bytes32 sentinelSlot = keccak256("give.bootstrap.completed");
        vm.store(sentinelAddr, sentinelSlot, bytes32(0));

        bootstrap = new Bootstrap();
        config = bootstrap.loadLocalConfig();
        config.broadcast = false;
        config.allowRedeploy = false;
    }

    function testDeterministicDeploymentAcrossSnapshots() public {
        uint256 snapshot = vm.snapshot();
        Bootstrap.Deployment memory first = bootstrap.execute(config);
        vm.revertTo(snapshot);
        Bootstrap.Deployment memory second = bootstrap.execute(config);

        assertEq(first.core, second.core, "core address mismatch");
        assertEq(first.acl, second.acl, "acl address mismatch");
        assertEq(first.vault, second.vault, "vault address mismatch");
        assertEq(first.adapter, second.adapter, "adapter address mismatch");
        assertEq(first.registry, second.registry, "registry address mismatch");
        assertEq(first.router, second.router, "router address mismatch");
    }

    function testBootstrapIdempotencyGuard() public {
        bootstrap.execute(config);
        vm.expectRevert(Bootstrap.AlreadyBootstrapped.selector);
        bootstrap.execute(config);
    }

    function testBootstrapWiresProtocolState() public {
        Bootstrap.Deployment memory deployment = bootstrap.execute(config);

        GiveProtocolCore core = GiveProtocolCore(deployment.core);
        ACLManager acl = ACLManager(deployment.acl);
        GiveVault4626 vault = GiveVault4626(payable(deployment.vault));
        DonationRouter router = DonationRouter(payable(deployment.router));

        // Governance wiring
        assertEq(uint256(uint160(address(core.aclManager()))), uint256(uint160(deployment.acl)));
        assertTrue(acl.hasRole(VaultModule.MANAGER_ROLE, address(core)));
        assertTrue(acl.hasRole(AdapterModule.MANAGER_ROLE, config.admin));
        assertTrue(acl.hasRole(RiskModule.MANAGER_ROLE, address(core)));

        // Sentinel recorded
        address sentinelAddr = address(uint160(uint256(keccak256("give.bootstrap.sentinel"))));
        bytes32 sentinelSlot = keccak256("give.bootstrap.completed");
        assertEq(vm.load(sentinelAddr, sentinelSlot), bytes32(uint256(1)));

        // Vault wiring
        assertEq(uint256(uint160(vault.donationRouter())), uint256(uint160(deployment.router)));
        assertFalse(vault.emergencyShutdownActive());

        // Adapter configuration
        (address adapterAsset, address adapterVault,, bool adapterActive) = core.getAdapterConfig(deployment.adapterId);
        assertEq(uint256(uint160(adapterAsset)), uint256(uint160(address(vault.asset()))));
        assertEq(uint256(uint160(adapterVault)), uint256(uint160(deployment.vault)));
        assertTrue(adapterActive);

        // Donation router wiring
        assertTrue(router.authorizedCallers(deployment.vault));

        // Risk configuration propagated
        GiveTypes.RiskConfig memory riskCfg = core.getRiskConfig(deployment.riskId);
        assertEq(riskCfg.maxDeposit, config.riskMaxDeposit);
        assertEq(riskCfg.maxBorrow, config.riskMaxBorrow);

        assertEq(vault.cashBufferBps(), config.cashBufferBps);
        assertEq(vault.slippageBps(), config.slippageBps);
        assertEq(vault.maxLossBps(), config.maxLossBps);
    }
}
