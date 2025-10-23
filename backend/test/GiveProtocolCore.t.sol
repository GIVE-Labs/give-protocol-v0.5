// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {GiveProtocolCore} from "../src/core/GiveProtocolCore.sol";
import {DataTypes} from "../src/libraries/types/DataTypes.sol";
import {ModuleBase} from "../src/libraries/utils/ModuleBase.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GiveProtocolCoreTest
 * @notice Basic tests for GiveProtocolCore V2
 */
contract GiveProtocolCoreTest is Test {
    GiveProtocolCore public implementation;
    ERC1967Proxy public proxy;
    GiveProtocolCore public protocol;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public guardian = address(0x3);
    address public user1 = address(0x4);
    address public user2 = address(0x5);
    
    uint256 public constant PROTOCOL_FEE_BPS = 1000; // 10%
    
    event ProtocolInitialized(address indexed treasury, address indexed guardian, uint256 protocolFeeBps);
    
    function setUp() public {
        vm.label(admin, "Admin");
        vm.label(treasury, "Treasury");
        vm.label(guardian, "Guardian");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        
        // Deploy implementation
        implementation = new GiveProtocolCore();
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            GiveProtocolCore.initialize.selector,
            treasury,
            guardian,
            PROTOCOL_FEE_BPS
        );
        
        // Deploy proxy
        vm.prank(admin);
        proxy = new ERC1967Proxy(address(implementation), initData);
        
        // Create protocol interface
        protocol = GiveProtocolCore(address(proxy));
    }
    
    function test_Initialization() public view {
        assertEq(protocol.getTreasury(), treasury, "Treasury should be set");
        assertEq(protocol.getGuardian(), guardian, "Guardian should be set");
        
        DataTypes.FeeConfig memory feeConfig = protocol.getFeeConfig();
        assertEq(feeConfig.protocolFeeBps, PROTOCOL_FEE_BPS, "Protocol fee should be set");
        assertEq(feeConfig.treasuryAddress, treasury, "Fee treasury should be set");
    }
    
    function test_RiskParameters() public view {
        DataTypes.RiskParameters memory riskParams = protocol.getRiskParameters();
        
        assertEq(riskParams.maxAdaptersPerVault, 5, "Max adapters should be 5");
        assertEq(riskParams.maxAdapterAllocation, 9500, "Max allocation should be 95%");
        assertEq(riskParams.minAdapterAllocation, 500, "Min allocation should be 5%");
        assertEq(riskParams.maxSlippageBps, 200, "Max slippage should be 2%");
        assertEq(riskParams.maxLossBps, 500, "Max loss should be 5%");
    }
    
    function test_AccessControl() public view {
        assertTrue(protocol.hasRole(protocol.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE");
        assertTrue(protocol.hasRole(ModuleBase.VAULT_MANAGER_ROLE, admin), "Admin should have VAULT_MANAGER_ROLE");
        assertTrue(protocol.hasRole(ModuleBase.CAMPAIGN_CURATOR_ROLE, admin), "Admin should have CAMPAIGN_CURATOR_ROLE");
        assertTrue(protocol.hasRole(ModuleBase.PAUSER_ROLE, guardian), "Guardian should have PAUSER_ROLE");
        assertTrue(protocol.hasRole(ModuleBase.GUARDIAN_ROLE, guardian), "Guardian should have GUARDIAN_ROLE");
    }
    
    function test_PauseUnpause() public {
        assertFalse(protocol.isGlobalPaused(), "Should not be paused initially");
        
        vm.prank(guardian);
        protocol.setPaused(true);
        
        assertTrue(protocol.isGlobalPaused(), "Should be paused");
        
        vm.prank(guardian);
        protocol.setPaused(false);
        
        assertFalse(protocol.isGlobalPaused(), "Should be unpaused");
    }
    
    function test_SetTreasury() public {
        address newTreasury = address(0x999);
        
        vm.prank(admin);
        protocol.setTreasury(newTreasury);
        
        assertEq(protocol.getTreasury(), newTreasury, "Treasury should be updated");
    }
    
    function test_RevertWhen_SetTreasuryUnauthorized() public {
        address newTreasury = address(0x999);
        
        vm.expectRevert();
        vm.prank(user1);
        protocol.setTreasury(newTreasury);
    }
    
    function test_UpdateProtocolFee() public {
        uint256 newFeeBps = 500; // 5%
        
        vm.prank(admin);
        protocol.setProtocolFee(newFeeBps);
        
        DataTypes.FeeConfig memory feeConfig = protocol.getFeeConfig();
        assertEq(feeConfig.protocolFeeBps, newFeeBps, "Protocol fee should be updated");
    }
    
    function test_RevertWhen_UpdateProtocolFeeExceedsMax() public {
        uint256 invalidFee = 2001; // > 20%
        
        vm.expectRevert();
        vm.prank(admin);
        protocol.setProtocolFee(invalidFee);
    }
    
    function test_GetImplementation() public view {
        address impl = protocol.getImplementation();
        assertEq(impl, address(implementation), "Should return correct implementation");
    }
    
    function test_Upgrade() public {
        // Deploy new implementation
        GiveProtocolCore newImplementation = new GiveProtocolCore();
        
        address oldImpl = protocol.getImplementation();
        
        // Upgrade
        vm.prank(admin);
        protocol.upgradeToAndCall(address(newImplementation), "");
        
        address newImpl = protocol.getImplementation();
        
        assertTrue(newImpl != oldImpl, "Implementation should be different");
        assertEq(newImpl, address(newImplementation), "Should be new implementation");
        
        // Verify state is preserved
        assertEq(protocol.getTreasury(), treasury, "Treasury should be preserved");
        assertEq(protocol.getGuardian(), guardian, "Guardian should be preserved");
    }
    
    function test_RevertWhen_UpgradeUnauthorized() public {
        GiveProtocolCore newImplementation = new GiveProtocolCore();
        
        vm.expectRevert();
        vm.prank(user1);
        protocol.upgradeToAndCall(address(newImplementation), "");
    }
    
    function test_ProtocolMetrics() public view {
        DataTypes.ProtocolMetrics memory metrics = protocol.getProtocolMetrics();
        
        // Initially all metrics should be 0
        assertEq(metrics.totalValueLocked, 0, "TVL should be 0");
        assertEq(metrics.totalYieldGenerated, 0, "Total yield should be 0");
        assertEq(metrics.totalYieldDistributed, 0, "Distributed yield should be 0");
        assertEq(metrics.totalProtocolFees, 0, "Protocol fees should be 0");
        assertEq(metrics.totalUsers, 0, "Total users should be 0");
        assertEq(metrics.totalCampaigns, 0, "Total campaigns should be 0");
    }
}
