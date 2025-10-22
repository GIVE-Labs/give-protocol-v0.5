// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/core/GiveProtocolCore.sol";
import "../src/governance/ACLManager.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/AdapterModule.sol";
import "../src/types/GiveTypes.sol";

contract GiveProtocolCoreTest is Test {
    ACLManager internal acl;
    GiveProtocolCore internal core;
    address internal superAdmin;
    address internal upgrader;
    address internal manager;

    function setUp() public {
        superAdmin = makeAddr("superAdmin");
        upgrader = makeAddr("upgrader");
        manager = makeAddr("manager");

        ACLManager implementation = new ACLManager();
        bytes memory initData = abi.encodeWithSelector(ACLManager.initialize.selector, superAdmin, upgrader);
        ERC1967Proxy aclProxy = new ERC1967Proxy(address(implementation), initData);
        acl = ACLManager(address(aclProxy));

        vm.prank(superAdmin);
        acl.createRole(VaultModule.MANAGER_ROLE, superAdmin);
        vm.prank(superAdmin);
        acl.createRole(AdapterModule.MANAGER_ROLE, superAdmin);

        GiveProtocolCore coreImpl = new GiveProtocolCore();
        ERC1967Proxy coreProxy = new ERC1967Proxy(address(coreImpl), "");
        core = GiveProtocolCore(address(coreProxy));

        vm.prank(superAdmin);
        core.initialize(address(acl));
    }

    function testConfigureVaultRequiresRole() public {
        VaultModule.VaultConfigInput memory input = VaultModule.VaultConfigInput({
            id: keccak256("vault"),
            proxy: address(0x1234),
            implementation: address(0x5678),
            asset: address(0x9),
            adapterId: keccak256("adapter"),
            donationModuleId: bytes32(0),
            riskId: bytes32(0),
            cashBufferBps: 100,
            slippageBps: 50,
            maxLossBps: 50
        });

        vm.expectRevert();
        core.configureVault(input.id, input);

        vm.prank(superAdmin);
        acl.grantRole(VaultModule.MANAGER_ROLE, manager);

        vm.prank(manager);
        core.configureVault(input.id, input);
    }

    function testConfigureAdapterRequiresRole() public {
        AdapterModule.AdapterConfigInput memory cfg = AdapterModule.AdapterConfigInput({
            id: keccak256("adapter"),
            proxy: address(0x123),
            implementation: address(0x456),
            asset: address(0x789),
            vault: address(0xABC),
            kind: GiveTypes.AdapterKind.CompoundingValue,
            metadataHash: bytes32(0)
        });

        vm.expectRevert();
        core.configureAdapter(cfg.id, cfg);

        vm.prank(superAdmin);
        acl.grantRole(AdapterModule.MANAGER_ROLE, manager);

        vm.prank(manager);
        core.configureAdapter(cfg.id, cfg);
    }
}
