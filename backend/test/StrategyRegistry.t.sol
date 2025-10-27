// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/governance/ACLManager.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/types/GiveTypes.sol";

contract StrategyRegistryTest is Test {
    ACLManager internal acl;
    StrategyRegistry internal registry;
    address internal superAdmin;
    address internal upgrader;
    address internal adapter;
    bytes32 internal strategyId;

    function setUp() public {
        superAdmin = makeAddr("superAdmin");
        upgrader = makeAddr("upgrader");
        adapter = makeAddr("adapter");
        strategyId = keccak256("strategy.primary");

        ACLManager aclImpl = new ACLManager();
        ERC1967Proxy aclProxy =
            new ERC1967Proxy(address(aclImpl), abi.encodeCall(ACLManager.initialize, (superAdmin, upgrader)));
        acl = ACLManager(address(aclProxy));

        StrategyRegistry registryImpl = new StrategyRegistry();
        ERC1967Proxy registryProxy =
            new ERC1967Proxy(address(registryImpl), abi.encodeCall(StrategyRegistry.initialize, (address(acl))));
        registry = StrategyRegistry(address(registryProxy));
    }

    function _registerDefault() internal {
        StrategyRegistry.StrategyInput memory input = StrategyRegistry.StrategyInput({
            id: strategyId,
            adapter: adapter,
            riskTier: bytes32("tier.low"),
            maxTvl: 1_000 ether,
            metadataHash: keccak256("metadata:v1")
        });

        vm.prank(superAdmin);
        registry.registerStrategy(input);
    }

    function testRegisterStrategyStoresConfig() public {
        _registerDefault();

        GiveTypes.StrategyConfig memory cfg = registry.getStrategy(strategyId);
        assertEq(cfg.id, strategyId);
        assertEq(cfg.adapter, adapter);
        assertEq(cfg.maxTvl, 1_000 ether);
        assertEq(cfg.metadataHash, keccak256("metadata:v1"));
        assertEq(uint256(cfg.status), uint256(GiveTypes.StrategyStatus.Active));
        assertTrue(cfg.exists);

        bytes32[] memory ids = registry.listStrategyIds();
        assertEq(ids.length, 1);
        assertEq(ids[0], strategyId);
    }

    function testUpdateStrategyMutatesFields() public {
        _registerDefault();

        StrategyRegistry.StrategyInput memory updateInput = StrategyRegistry.StrategyInput({
            id: strategyId,
            adapter: makeAddr("adapter-2"),
            riskTier: bytes32("tier.mid"),
            maxTvl: 2_500 ether,
            metadataHash: keccak256("metadata:v2")
        });

        vm.prank(superAdmin);
        registry.updateStrategy(updateInput);

        GiveTypes.StrategyConfig memory cfg = registry.getStrategy(strategyId);
        assertEq(cfg.adapter, updateInput.adapter);
        assertEq(cfg.maxTvl, updateInput.maxTvl);
        assertEq(cfg.metadataHash, updateInput.metadataHash);
        assertEq(cfg.riskTier, updateInput.riskTier);
    }

    function testSetStrategyStatus() public {
        _registerDefault();

        vm.prank(superAdmin);
        registry.setStrategyStatus(strategyId, GiveTypes.StrategyStatus.FadingOut);

        GiveTypes.StrategyConfig memory cfg = registry.getStrategy(strategyId);
        assertEq(uint256(cfg.status), uint256(GiveTypes.StrategyStatus.FadingOut));
    }

    function testRegisterStrategyVaultTracksDeployments() public {
        _registerDefault();
        address vault = makeAddr("vault");

        vm.prank(superAdmin);
        registry.registerStrategyVault(strategyId, vault);

        address[] memory vaults = registry.getStrategyVaults(strategyId);
        assertEq(vaults.length, 1);
        assertEq(vaults[0], vault);
    }

    function testRevertsForUnknownStrategy() public {
        vm.expectRevert(abi.encodeWithSelector(StrategyRegistry.StrategyNotFound.selector, strategyId));
        registry.getStrategy(strategyId);
    }

    function testOnlyStrategyAdminCanManage() public {
        StrategyRegistry.StrategyInput memory input = StrategyRegistry.StrategyInput({
            id: strategyId,
            adapter: adapter,
            riskTier: bytes32("tier.low"),
            maxTvl: 1_000 ether,
            metadataHash: keccak256("metadata:v1")
        });

        address intruder = makeAddr("intruder");
        vm.expectRevert(
            abi.encodeWithSelector(StrategyRegistry.Unauthorized.selector, acl.strategyAdminRole(), intruder)
        );
        vm.prank(intruder);
        registry.registerStrategy(input);
    }
}
