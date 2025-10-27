// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./utils/BaseProtocolTest.sol";
import "../src/modules/RiskModule.sol";
import "../src/modules/VaultModule.sol";
import "../src/modules/EmergencyModule.sol";
import "../src/modules/AdapterModule.sol";
import "../src/adapters/kinds/CompoundingAdapter.sol";
import "../src/types/GiveTypes.sol";

contract RiskEmergencyTest is BaseProtocolTest {
    address internal depositor;
    bytes32 internal constant TEST_RISK_ID = keccak256("risk.test");
    bytes32 internal constant TEST_ADAPTER_ID = keccak256("adapter.emergency");
    CompoundingAdapter internal compAdapter;

    event RiskLimitBreached(
        bytes32 indexed vaultId, bytes32 indexed riskId, uint8 limitType, uint256 currentValue, uint256 maxAllowed
    );

    function setUp() public override {
        super.setUp();
        depositor = makeAddr("depositor");

        compAdapter = new CompoundingAdapter(TEST_ADAPTER_ID, address(asset), address(vault));

        vm.startPrank(admin);
        core.configureAdapter(
            TEST_ADAPTER_ID,
            AdapterModule.AdapterConfigInput({
                id: TEST_ADAPTER_ID,
                proxy: address(compAdapter),
                implementation: address(compAdapter),
                asset: address(asset),
                vault: address(vault),
                kind: GiveTypes.AdapterKind.CompoundingValue,
                metadataHash: bytes32("emergency")
            })
        );
        vault.grantRole(vault.DEFAULT_ADMIN_ROLE(), address(core));
        vault.setActiveAdapter(compAdapter);
        vm.stopPrank();
    }

    function testRiskConfigValidationReverts() public {
        RiskModule.RiskConfigInput memory invalidCfg = RiskModule.RiskConfigInput({
            id: TEST_RISK_ID,
            ltvBps: 9_500,
            liquidationThresholdBps: 9_000,
            liquidationPenaltyBps: 200,
            borrowCapBps: 5_000,
            depositCapBps: 9_500,
            dataHash: bytes32(0),
            maxDeposit: 1_000e18,
            maxBorrow: 800e18
        });

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(RiskModule.InvalidRiskParameters.selector, TEST_RISK_ID, uint8(2)));
        core.configureRisk(TEST_RISK_ID, invalidCfg);
        vm.stopPrank();
    }

    function testDepositRespectsRiskCap() public {
        _configureRisk(1_000e18, 800e18);

        asset.mint(depositor, 1_500e18);

        vm.startPrank(depositor);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(600e18, depositor);
        vm.expectEmit(true, true, true, true);
        emit RiskLimitBreached(deployment.vaultId, TEST_RISK_ID, uint8(1), 1_100e18, 1_000e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                RiskModule.RiskLimitExceeded.selector, TEST_RISK_ID, deployment.vaultId, uint8(1), 1_100e18, 1_000e18
            )
        );
        vault.deposit(500e18, depositor);
        vm.stopPrank();

        GiveTypes.RiskConfig memory stored = core.getRiskConfig(TEST_RISK_ID);
        assertEq(stored.version, 1);

        vm.startPrank(admin);
        core.configureRisk(
            TEST_RISK_ID,
            RiskModule.RiskConfigInput({
                id: TEST_RISK_ID,
                ltvBps: 7_000,
                liquidationThresholdBps: 8_000,
                liquidationPenaltyBps: 300,
                borrowCapBps: 4_000,
                depositCapBps: 9_000,
                dataHash: bytes32(0),
                maxDeposit: 2_000e18,
                maxBorrow: 1_500e18
            })
        );
        core.assignVaultRisk(deployment.vaultId, TEST_RISK_ID);
        vm.stopPrank();

        GiveTypes.RiskConfig memory updated = core.getRiskConfig(TEST_RISK_ID);
        assertEq(updated.version, 2);
        assertEq(updated.maxDeposit, 2_000e18);
        assertEq(updated.maxBorrow, 1_500e18);
    }

    function testEmergencyFlowPauseWithdrawResume() public {
        _configureRisk(2_000e18, 1_500e18);

        asset.mint(depositor, 1_000e18);

        vm.startPrank(depositor);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(800e18, depositor);
        vm.stopPrank();

        vm.startPrank(emergencyCouncil);
        core.triggerEmergency(deployment.vaultId, EmergencyModule.EmergencyAction.Pause, bytes(""));
        vm.stopPrank();

        assertTrue(vault.paused());
        assertTrue(vault.emergencyShutdownActive());

        EmergencyModule.EmergencyWithdrawParams memory params =
            EmergencyModule.EmergencyWithdrawParams({clearAdapter: true});

        vm.startPrank(emergencyCouncil);
        core.triggerEmergency(deployment.vaultId, EmergencyModule.EmergencyAction.Withdraw, abi.encode(params));
        vm.stopPrank();

        assertEq(asset.balanceOf(address(vault)), 800e18);
        assertEq(address(vault.activeAdapter()), address(0));

        vm.startPrank(emergencyCouncil);
        core.triggerEmergency(deployment.vaultId, EmergencyModule.EmergencyAction.Unpause, bytes(""));
        vm.stopPrank();

        assertFalse(vault.paused());
        assertFalse(vault.emergencyShutdownActive());
    }

    function _configureRisk(uint256 maxDeposit, uint256 maxBorrow) internal {
        vm.startPrank(admin);
        core.configureRisk(
            TEST_RISK_ID,
            RiskModule.RiskConfigInput({
                id: TEST_RISK_ID,
                ltvBps: 7_000,
                liquidationThresholdBps: 8_500,
                liquidationPenaltyBps: 300,
                borrowCapBps: 4_000,
                depositCapBps: 9_500,
                dataHash: bytes32(0),
                maxDeposit: maxDeposit,
                maxBorrow: maxBorrow
            })
        );

        core.configureVault(
            deployment.vaultId,
            VaultModule.VaultConfigInput({
                id: deployment.vaultId,
                proxy: address(vault),
                implementation: address(vault),
                asset: address(asset),
                adapterId: TEST_ADAPTER_ID,
                donationModuleId: bytes32(0),
                riskId: TEST_RISK_ID,
                cashBufferBps: 100,
                slippageBps: 50,
                maxLossBps: 50
            })
        );
        core.assignVaultRisk(deployment.vaultId, TEST_RISK_ID);
        vm.stopPrank();
    }
}
