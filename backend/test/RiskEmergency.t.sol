// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/core/GiveProtocolCore.sol";
import "../src/governance/ACLManager.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/RiskModule.sol";
import "../src/modules/EmergencyModule.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/adapters/kinds/CompoundingAdapter.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "../src/types/GiveTypes.sol";

contract RiskEmergencyTest is Test {
    ACLManager internal acl;
    GiveProtocolCore internal core;
    MockAsset internal asset;
    GiveVault4626 internal vault;
    CompoundingAdapter internal adapter;

    address internal superAdmin;
    address internal upgrader;
    address internal emergencyOperator;
    address internal depositor;

    bytes32 internal vaultId;
    bytes32 internal riskId;
    bytes32 internal adapterId;

    function setUp() public {
        superAdmin = makeAddr("superAdmin");
        upgrader = makeAddr("upgrader");
        emergencyOperator = makeAddr("emergency");
        depositor = makeAddr("depositor");

        asset = new MockAsset();
        vault = new GiveVault4626(IERC20(address(asset)), "Give Vault", "GV", address(this));
        vaultId = keccak256(abi.encodePacked("vault", address(vault)));
        riskId = keccak256("risk-id-1");
        adapterId = keccak256("adapter-1");

        ACLManager implementation = new ACLManager();
        ERC1967Proxy aclProxy = new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(ACLManager.initialize.selector, superAdmin, upgrader)
        );
        acl = ACLManager(address(aclProxy));

        GiveProtocolCore impl = new GiveProtocolCore();
        ERC1967Proxy coreProxy = new ERC1967Proxy(address(impl), "");
        core = GiveProtocolCore(address(coreProxy));

        // Wire ACL manager
        vm.prank(superAdmin);
        core.initialize(address(acl));
        vault.setACLManager(address(acl));

        // Create required roles
        vm.startPrank(superAdmin);
        acl.createRole(VaultModule.MANAGER_ROLE, superAdmin);
        acl.createRole(RiskModule.MANAGER_ROLE, superAdmin);
        acl.createRole(keccak256("EMERGENCY_ROLE"), superAdmin);
        acl.createRole(vault.PAUSER_ROLE(), superAdmin);
        acl.createRole(vault.DEFAULT_ADMIN_ROLE(), superAdmin);
        acl.grantRole(VaultModule.MANAGER_ROLE, address(this));
        acl.grantRole(RiskModule.MANAGER_ROLE, address(this));
        acl.grantRole(RiskModule.MANAGER_ROLE, address(core));
        acl.grantRole(keccak256("EMERGENCY_ROLE"), emergencyOperator);
        acl.grantRole(vault.PAUSER_ROLE(), address(core));
        acl.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(core));
        vm.stopPrank();

        adapter = new CompoundingAdapter(adapterId, address(asset), address(vault));
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(this));
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(core));
    }

    function testRiskConfigValidationReverts() public {
        RiskModule.RiskConfigInput memory invalidCfg = RiskModule.RiskConfigInput({
            id: riskId,
            ltvBps: 9_500,
            liquidationThresholdBps: 9_000,
            liquidationPenaltyBps: 200,
            borrowCapBps: 5_000,
            depositCapBps: 9_500,
            dataHash: bytes32(0),
            maxDeposit: 1_000e18,
            maxBorrow: 800e18
        });

        vm.expectRevert(abi.encodeWithSelector(RiskModule.InvalidRiskParameters.selector, riskId, uint8(2)));
        core.configureRisk(riskId, invalidCfg);
    }

    function testDepositRespectsRiskCap() public {
        _configureRiskAndVault(1_000e18, 800e18);

        asset.mint(depositor, 1_500e18);
        vm.startPrank(depositor);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(600e18, depositor);
        vm.expectEmit(true, true, true, true);
        emit RiskModule.RiskLimitBreached(vaultId, riskId, 1, 1_100e18, 1_000e18);
        vm.expectRevert(
            abi.encodeWithSelector(RiskModule.RiskLimitExceeded.selector, riskId, vaultId, uint8(1), 1_100e18, 1_000e18)
        );
        vault.deposit(500e18, depositor);
        vm.stopPrank();

        GiveTypes.RiskConfig memory stored = core.getRiskConfig(riskId);
        assertEq(stored.version, 1);

        // Update config and ensure version increments
        RiskModule.RiskConfigInput memory updated = RiskModule.RiskConfigInput({
            id: riskId,
            ltvBps: 7_000,
            liquidationThresholdBps: 8_000,
            liquidationPenaltyBps: 300,
            borrowCapBps: 4_000,
            depositCapBps: 9_000,
            dataHash: bytes32(0),
            maxDeposit: 2_000e18,
            maxBorrow: 1_500e18
        });
        core.configureRisk(riskId, updated);
        core.assignVaultRisk(vaultId, riskId);
        GiveTypes.RiskConfig memory updatedStored = core.getRiskConfig(riskId);
        assertEq(updatedStored.version, 2);
        assertEq(updatedStored.maxDeposit, 2_000e18);
    }

    function testEmergencyFlowPauseWithdrawResume() public {
        _configureRiskAndVault(2_000e18, 1_500e18);

        asset.mint(depositor, 1_000e18);
        vault.setActiveAdapter(IYieldAdapter(address(adapter)));
        vm.startPrank(depositor);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(800e18, depositor);
        vm.stopPrank();

        vm.prank(emergencyOperator);
        core.triggerEmergency(vaultId, EmergencyModule.EmergencyAction.Pause, bytes(""));
        assertTrue(vault.paused());
        assertTrue(vault.emergencyShutdownActive());

        EmergencyModule.EmergencyWithdrawParams memory params = EmergencyModule.EmergencyWithdrawParams({
            clearAdapter: true
        });

        vm.prank(emergencyOperator);
        core.triggerEmergency(
            vaultId, EmergencyModule.EmergencyAction.Withdraw, abi.encode(params)
        );
        assertEq(asset.balanceOf(address(vault)), 800e18);
        assertEq(address(vault.activeAdapter()), address(0));

        vm.prank(emergencyOperator);
        core.triggerEmergency(vaultId, EmergencyModule.EmergencyAction.Unpause, bytes(""));
        assertFalse(vault.paused());
        assertFalse(vault.emergencyShutdownActive());
    }

    function _configureRiskAndVault(uint256 maxDeposit, uint256 maxBorrow) internal {
        RiskModule.RiskConfigInput memory cfg = RiskModule.RiskConfigInput({
            id: riskId,
            ltvBps: 7_000,
            liquidationThresholdBps: 8_500,
            liquidationPenaltyBps: 300,
            borrowCapBps: 4_000,
            depositCapBps: 9_500,
            dataHash: bytes32(0),
            maxDeposit: maxDeposit,
            maxBorrow: maxBorrow
        });

        core.configureRisk(riskId, cfg);

        VaultModule.VaultConfigInput memory vaultCfg = VaultModule.VaultConfigInput({
            id: vaultId,
            proxy: address(vault),
            implementation: address(vault),
            asset: address(asset),
            adapterId: adapterId,
            donationModuleId: bytes32(0),
            riskId: riskId,
            cashBufferBps: 100,
            slippageBps: 50,
            maxLossBps: 50
        });

        core.configureVault(vaultId, vaultCfg);
        core.assignVaultRisk(vaultId, riskId);
    }
}

contract MockAsset is ERC20("Mock Asset", "MA") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
