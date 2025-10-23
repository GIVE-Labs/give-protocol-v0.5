// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/governance/ACLManager.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/types/GiveTypes.sol";

contract CampaignRegistryTest is Test {
    ACLManager internal acl;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;

    address internal superAdmin;
    address internal upgrader;
    bytes32 internal strategyId;
    bytes32 internal campaignId;

    function setUp() public {
        superAdmin = makeAddr("superAdmin");
        upgrader = makeAddr("upgrader");
        strategyId = keccak256("strategy.default");
        campaignId = keccak256("campaign.alpha");

        ACLManager aclImpl = new ACLManager();
        ERC1967Proxy aclProxy =
            new ERC1967Proxy(address(aclImpl), abi.encodeCall(ACLManager.initialize, (superAdmin, upgrader)));
        acl = ACLManager(address(aclProxy));

        StrategyRegistry strategyImpl = new StrategyRegistry();
        ERC1967Proxy strategyProxy =
            new ERC1967Proxy(address(strategyImpl), abi.encodeCall(StrategyRegistry.initialize, (address(acl))));
        strategyRegistry = StrategyRegistry(address(strategyProxy));

        StrategyRegistry.StrategyInput memory strategyInput = StrategyRegistry.StrategyInput({
            id: strategyId,
            adapter: makeAddr("adapter"),
            riskTier: bytes32("tier.low"),
            maxTvl: 1_000 ether,
            metadataHash: keccak256("strategy.metadata")
        });

        vm.prank(superAdmin);
        strategyRegistry.registerStrategy(strategyInput);

        CampaignRegistry campaignImpl = new CampaignRegistry();
        ERC1967Proxy campaignProxy = new ERC1967Proxy(
            address(campaignImpl), abi.encodeCall(CampaignRegistry.initialize, (address(acl), address(strategyRegistry)))
        );
        campaignRegistry = CampaignRegistry(address(campaignProxy));
    }

    function _submitCampaign() internal {
        CampaignRegistry.CampaignInput memory input = CampaignRegistry.CampaignInput({
            id: campaignId,
            payoutRecipient: makeAddr("payout"),
            strategyId: strategyId,
            metadataHash: keccak256("campaign.metadata"),
            targetStake: 10_000 ether,
            minStake: 1_000 ether,
            fundraisingStart: uint64(block.timestamp),
            fundraisingEnd: uint64(block.timestamp + 7 days)
        });

        vm.prank(superAdmin);
        campaignRegistry.submitCampaign(input);
    }

    function testSubmitCampaignStoresConfig() public {
        _submitCampaign();

        GiveTypes.CampaignConfig memory cfg = campaignRegistry.getCampaign(campaignId);
        assertEq(cfg.id, campaignId);
        assertEq(cfg.strategyId, strategyId);
        assertEq(cfg.payoutRecipient, makeAddr("payout"));
        assertEq(uint256(cfg.status), uint256(GiveTypes.CampaignStatus.Submitted));
        assertTrue(cfg.exists);
    }

    function testApproveCampaignUpdatesStatus() public {
        _submitCampaign();
        address curator = makeAddr("curator");

        vm.prank(superAdmin);
        campaignRegistry.approveCampaign(campaignId, curator);

        GiveTypes.CampaignConfig memory cfg = campaignRegistry.getCampaign(campaignId);
        assertEq(cfg.curator, curator);
        assertEq(uint256(cfg.status), uint256(GiveTypes.CampaignStatus.Approved));
    }

    function testStakeLifecycle() public {
        _submitCampaign();
        vm.prank(superAdmin);
        campaignRegistry.setCampaignStatus(campaignId, GiveTypes.CampaignStatus.Active);

        address supporter = makeAddr("supporter");

        vm.prank(superAdmin);
        campaignRegistry.recordStakeDeposit(campaignId, supporter, 500 ether);

        GiveTypes.StakePosition memory position = campaignRegistry.getStakePosition(campaignId, supporter);
        assertEq(position.amount, 500 ether);
        assertFalse(position.requestedExit);

        vm.prank(superAdmin);
        campaignRegistry.requestStakeExit(campaignId, supporter, 200 ether);

        position = campaignRegistry.getStakePosition(campaignId, supporter);
        assertEq(position.amount, 300 ether);
        assertEq(position.pendingWithdrawal, 200 ether);
        assertTrue(position.requestedExit);

        vm.prank(superAdmin);
        campaignRegistry.finalizeStakeExit(campaignId, supporter, 200 ether);

        position = campaignRegistry.getStakePosition(campaignId, supporter);
        assertEq(position.amount, 300 ether);
        assertEq(position.pendingWithdrawal, 0);
        assertFalse(position.requestedExit);
    }

    function testScheduleCheckpoint() public {
        _submitCampaign();
        vm.prank(superAdmin);
        campaignRegistry.setCampaignStatus(campaignId, GiveTypes.CampaignStatus.Active);

        CampaignRegistry.CheckpointInput memory input = CampaignRegistry.CheckpointInput({
            windowStart: uint64(block.timestamp + 1 days),
            windowEnd: uint64(block.timestamp + 2 days),
            executionDeadline: uint64(block.timestamp + 3 days),
            quorumBps: 6_000
        });

        vm.prank(superAdmin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(campaignId, input);
        assertEq(checkpointId, 0);

        vm.prank(superAdmin);
        campaignRegistry.updateCheckpointStatus(campaignId, checkpointId, GiveTypes.CheckpointStatus.Voting);

        (
            uint64 windowStart,
            uint64 windowEnd,
            uint64 executionDeadline,
            uint16 quorumBps,
            GiveTypes.CheckpointStatus status,
            uint256 totalEligibleStake
        ) = campaignRegistry.getCheckpoint(campaignId, checkpointId);

        assertEq(windowStart, input.windowStart);
        assertEq(windowEnd, input.windowEnd);
        assertEq(executionDeadline, input.executionDeadline);
        assertEq(quorumBps, input.quorumBps);
        assertEq(uint256(status), uint256(GiveTypes.CheckpointStatus.Voting));
        assertEq(totalEligibleStake, 0);
    }

    function testSetCampaignVaultRecordsMetadata() public {
        _submitCampaign();
        address vault = makeAddr("vault");
        bytes32 lockProfile = keccak256("lock.weekly");

        vm.prank(superAdmin);
        campaignRegistry.setCampaignVault(campaignId, vault, lockProfile);

        GiveTypes.CampaignConfig memory cfg = campaignRegistry.getCampaign(campaignId);
        assertEq(cfg.vault, vault);
        assertEq(cfg.lockProfile, lockProfile);
    }
}
