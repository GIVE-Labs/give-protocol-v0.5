// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/core/GiveProtocolCore.sol";
import "../src/governance/ACLManager.sol";
import "../src/modules/SyntheticModule.sol";
import "../src/synthetic/SyntheticLogic.sol";
import "../src/synthetic/SyntheticProxy.sol";

contract SyntheticModuleTest is Test {
    ACLManager internal acl;
    GiveProtocolCore internal core;
    bytes32 internal constant SYNTH_ID = keccak256("synthetic.usdc");
    address internal manager;
    address internal user;

    function setUp() public {
        manager = makeAddr("manager");
        user = makeAddr("user");

        ACLManager implementation = new ACLManager();
        ERC1967Proxy aclProxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(ACLManager.initialize.selector, address(this), address(this))
        );
        acl = ACLManager(address(aclProxy));

        GiveProtocolCore coreImpl = new GiveProtocolCore();
        ERC1967Proxy coreProxy = new ERC1967Proxy(address(coreImpl), "");
        core = GiveProtocolCore(address(coreProxy));
        core.initialize(address(acl));

        acl.createRole(SyntheticModule.MANAGER_ROLE, address(this));
        acl.grantRole(SyntheticModule.MANAGER_ROLE, manager);
        acl.grantRole(core.ROLE_UPGRADER(), address(this));
        assertTrue(acl.hasRole(SyntheticModule.MANAGER_ROLE, manager));
    }

    function testConfigureAndMint() public {
        vm.startPrank(manager);
        core.configureSynthetic(
            SYNTH_ID,
            SyntheticModule.SyntheticConfigInput({
                id: SYNTH_ID,
                proxy: address(new SyntheticProxy(SYNTH_ID)),
                asset: address(0x1234)
            })
        );
        core.mintSynthetic(SYNTH_ID, user, 1_000);
        vm.stopPrank();

        (,, bool active) = core.getSyntheticConfig(SYNTH_ID);
        assertTrue(active);
        uint256 balance = core.getSyntheticBalance(SYNTH_ID, user);
        assertEq(balance, 1_000);
        assertEq(core.getSyntheticTotalSupply(SYNTH_ID), 1_000);

        vm.prank(manager);
        core.burnSynthetic(SYNTH_ID, user, 500);
        assertEq(core.getSyntheticBalance(SYNTH_ID, user), 500);
        assertEq(core.getSyntheticTotalSupply(SYNTH_ID), 500);
    }

    function testMintRequiresManagerRole() public {
        vm.expectRevert();
        core.mintSynthetic(SYNTH_ID, user, 100);
    }
}
