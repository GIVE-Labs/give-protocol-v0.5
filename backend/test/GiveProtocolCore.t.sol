// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/AdapterModule.sol";
import "../src/types/GiveTypes.sol";

contract GiveProtocolCoreTest is BaseProtocolTest {
    address internal manager;
    bytes32 internal constant NEW_VAULT_ID = keccak256("vault.test");
    bytes32 internal constant NEW_ADAPTER_ID = keccak256("adapter.test");

    function setUp() public override {
        super.setUp();
        manager = makeAddr("manager");

        _grantRole(VaultModule.MANAGER_ROLE, manager);
        _grantRole(AdapterModule.MANAGER_ROLE, manager);
    }

    function testConfigureVaultRequiresRole() public {
        VaultModule.VaultConfigInput memory cfg = VaultModule.VaultConfigInput({
            id: NEW_VAULT_ID,
            proxy: address(0x123456),
            implementation: address(0x654321),
            asset: address(asset),
            adapterId: NEW_ADAPTER_ID,
            donationModuleId: bytes32("donation"),
            riskId: bytes32("risk"),
            cashBufferBps: 150,
            slippageBps: 75,
            maxLossBps: 25
        });

        address unauthorized = makeAddr("unauthorized");

        vm.startPrank(unauthorized);
        vm.expectRevert(_expectUnauthorized(VaultModule.MANAGER_ROLE, unauthorized));
        core.configureVault(cfg.id, cfg);
        vm.stopPrank();

        vm.startPrank(manager);
        core.configureVault(cfg.id, cfg);
        vm.stopPrank();
    }

    function testConfigureAdapterRequiresRole() public {
        AdapterModule.AdapterConfigInput memory cfg = AdapterModule.AdapterConfigInput({
            id: NEW_ADAPTER_ID,
            proxy: address(adapter),
            implementation: address(adapter),
            asset: address(asset),
            vault: address(vault),
            kind: GiveTypes.AdapterKind.CompoundingValue,
            metadataHash: bytes32("meta")
        });

        address unauthorized = makeAddr("adapter-unauthed");

        vm.startPrank(unauthorized);
        vm.expectRevert(_expectUnauthorized(AdapterModule.MANAGER_ROLE, unauthorized));
        core.configureAdapter(cfg.id, cfg);
        vm.stopPrank();

        vm.startPrank(manager);
        core.configureAdapter(cfg.id, cfg);
        vm.stopPrank();

        (address assetAddress, address vaultAddress, GiveTypes.AdapterKind kind, bool active) =
            core.getAdapterConfig(cfg.id);

        assertEq(uint256(uint160(assetAddress)), uint256(uint160(address(asset))));
        assertEq(uint256(uint160(vaultAddress)), uint256(uint160(address(vault))));
        assertEq(uint8(kind), uint8(GiveTypes.AdapterKind.CompoundingValue));
        assertTrue(active);
    }
}
