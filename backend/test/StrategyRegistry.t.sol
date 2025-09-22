// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {Errors} from "../src/utils/Errors.sol";

contract StrategyRegistryTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal registry;

    address internal admin;
    address internal guardian;
    address internal other;

    address internal asset;
    address internal adapter;

    function setUp() public {
        admin = makeAddr("admin");
        guardian = makeAddr("guardian");
        other = makeAddr("other");
        asset = makeAddr("usdc");
        adapter = makeAddr("aaveAdapter");

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), guardian);

        registry = new StrategyRegistry(address(roleManager));
    }

    function _createDefaultStrategy() internal returns (uint64 id) {
        vm.prank(admin);
        id = registry.createStrategy(
            asset,
            adapter,
            RegistryTypes.RiskTier.Moderate,
            "ipfs://strategy-metadata",
            10_000 ether
        );
    }

    function testCreateStrategyStoresMetadata() public {
        uint64 id = _createDefaultStrategy();

        StrategyRegistry.Strategy memory strategy = registry.getStrategy(id);
        assertEq(strategy.id, id);
        assertEq(strategy.asset, asset);
        assertEq(strategy.adapter, adapter);
        assertEq(uint8(strategy.riskTier), uint8(RegistryTypes.RiskTier.Moderate));
        assertEq(uint8(strategy.status), uint8(RegistryTypes.StrategyStatus.Active));
        assertEq(strategy.maxTvl, 10_000 ether);
        assertEq(strategy.metadataURI, "ipfs://strategy-metadata");
        assertTrue(strategy.createdAt != 0);
    }

    function testCreateStrategyRevertsWhenDuplicatePair() public {
        _createDefaultStrategy();

        vm.prank(admin);
        vm.expectRevert(Errors.StrategyAlreadyExists.selector);
        registry.createStrategy(
            asset,
            adapter,
            RegistryTypes.RiskTier.Moderate,
            "ipfs://duplicate",
            100 ether
        );
    }

    function testUpdateStrategyChangesAdapterAndMetadata() public {
        uint64 id = _createDefaultStrategy();
        address newAdapter = makeAddr("newAdapter");

        vm.prank(admin);
        registry.updateStrategy(id, newAdapter, RegistryTypes.RiskTier.Aggressive, "ipfs://new-metadata", 20_000 ether);

        StrategyRegistry.Strategy memory strategy = registry.getStrategy(id);
        assertEq(strategy.adapter, newAdapter);
        assertEq(uint8(strategy.riskTier), uint8(RegistryTypes.RiskTier.Aggressive));
        assertEq(strategy.metadataURI, "ipfs://new-metadata");
        assertEq(strategy.maxTvl, 20_000 ether);
    }

    function testGuardianCannotActivateStrategy() public {
        uint64 id = _createDefaultStrategy();

        vm.prank(admin);
        registry.setStrategyStatus(id, RegistryTypes.StrategyStatus.FadingOut);

        vm.prank(guardian);
        vm.expectRevert(Errors.OperationNotAllowed.selector);
        registry.setStrategyStatus(id, RegistryTypes.StrategyStatus.Active);
    }

    function testGuardianCanFadeOutStrategy() public {
        uint64 id = _createDefaultStrategy();

        vm.prank(guardian);
        registry.setStrategyStatus(id, RegistryTypes.StrategyStatus.FadingOut);

        StrategyRegistry.Strategy memory strategy = registry.getStrategy(id);
        assertEq(uint8(strategy.status), uint8(RegistryTypes.StrategyStatus.FadingOut));
    }

    function testListStrategyIdsSupportsPagination() public {
        for (uint256 i = 0; i < 5; ++i) {
            vm.prank(admin);
            registry.createStrategy(
                makeAddr(string.concat("asset", vm.toString(i))),
                makeAddr(string.concat("adapter", vm.toString(i))),
                RegistryTypes.RiskTier.Conservative,
                string.concat("ipfs://", vm.toString(i)),
                1_000 ether
            );
        }

        uint64[] memory firstBatch = registry.listStrategyIds(0, 3);
        assertEq(firstBatch.length, 3);

        uint64[] memory secondBatch = registry.listStrategyIds(3, 3);
        assertEq(secondBatch.length, 2);
    }

    function testPauseAndUnpause() public {
        vm.prank(guardian);
        registry.pause();

        vm.prank(admin);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        registry.createStrategy(asset, adapter, RegistryTypes.RiskTier.Conservative, "uri", 1);

        vm.prank(guardian);
        registry.unpause();

        vm.prank(admin);
        registry.createStrategy(asset, makeAddr("adapter2"), RegistryTypes.RiskTier.Conservative, "uri2", 1);
    }

    function testUnauthorizedCannotCreate() public {
        vm.expectRevert();
        registry.createStrategy(asset, adapter, RegistryTypes.RiskTier.Conservative, "uri", 1);
    }
}
