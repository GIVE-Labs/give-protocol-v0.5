// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CampaignRegistry} from "../src/campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../src/manager/StrategyRegistry.sol";
import {RoleManager} from "../src/access/RoleManager.sol";
import {RegistryTypes} from "../src/manager/RegistryTypes.sol";
import {Errors} from "../src/utils/Errors.sol";

contract CampaignRegistryTest is Test {
    RoleManager internal roleManager;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;

    address internal admin;
    address internal curator;
    address internal treasury;
    address internal payout;

    uint64 internal strategyId;

    function setUp() public {
        admin = makeAddr("admin");
        curator = makeAddr("curator");
        treasury = makeAddr("treasury");
        payout = makeAddr("payout");

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_STRATEGY_ADMIN(), admin);

        strategyRegistry = new StrategyRegistry(address(roleManager));
        vm.prank(admin);
        strategyId = strategyRegistry.createStrategy(
            makeAddr("usdc"),
            makeAddr("adapter"),
            RegistryTypes.RiskTier.Moderate,
            "ipfs://strategy",
            100_000 ether
        );

        campaignRegistry = new CampaignRegistry(
            address(roleManager),
            treasury,
            address(strategyRegistry),
            0.0001 ether
        );
    }

    receive() external payable {}

    function _submitDefaultCampaign() internal returns (uint64 id) {
        vm.deal(address(this), 1 ether);
        id = campaignRegistry.submitCampaign{value: 0.0001 ether}(
            "ipfs://campaign",
            curator,
            payout,
            RegistryTypes.LockProfile.Days90
        );
    }

    function testSubmitCampaignStoresData() public {
        uint64 id = _submitDefaultCampaign();

        CampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(id);
        assertEq(campaign.id, id);
        assertEq(campaign.creator, address(this));
        assertEq(campaign.curator, curator);
        assertEq(campaign.payout, payout);
        assertEq(campaign.metadataURI, "ipfs://campaign");
        assertEq(uint8(campaign.defaultLock), uint8(RegistryTypes.LockProfile.Days90));
        assertEq(uint8(campaign.status), uint8(RegistryTypes.CampaignStatus.Submitted));
        assertEq(campaign.stake, uint96(0.0001 ether));
    }

    function testSubmitCampaignRequiresMinimumStake() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.StakeTooLow.selector, uint256(0), campaignRegistry.minimumStake())
        );
        campaignRegistry.submitCampaign("uri", curator, payout, RegistryTypes.LockProfile.Days30);
    }

    function testApproveCampaignActivatesAndRefundsStake() public {
        uint64 id = _submitDefaultCampaign();

        vm.prank(admin);
        campaignRegistry.approveCampaign(id);

        CampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(id);
        assertEq(uint8(campaign.status), uint8(RegistryTypes.CampaignStatus.Active));
        assertTrue(campaign.stakeRefunded);
        assertEq(address(this).balance, 1 ether); // stake refunded
    }

    function testRejectCampaignSlashesStakeToTreasury() public {
        uint64 id = _submitDefaultCampaign();

        uint256 treasuryBalanceBefore = treasury.balance;

        vm.startPrank(admin);
        campaignRegistry.rejectCampaign(id, true);
        vm.stopPrank();

        assertEq(treasury.balance, treasuryBalanceBefore + 0.0001 ether);
    }

    function testCuratorCanAttachStrategy() public {
        uint64 id = _submitDefaultCampaign();

        vm.prank(admin);
        campaignRegistry.approveCampaign(id);

        vm.prank(curator);
        campaignRegistry.attachStrategy(id, strategyId);

        uint64[] memory attached = campaignRegistry.getCampaignStrategies(id);
        assertEq(attached.length, 1);
        assertEq(attached[0], strategyId);
    }

    function testAttachFailsWhenStrategyInactive() public {
        uint64 id = _submitDefaultCampaign();

        vm.prank(admin);
        campaignRegistry.approveCampaign(id);

        vm.startPrank(admin);
        strategyRegistry.setStrategyStatus(strategyId, RegistryTypes.StrategyStatus.FadingOut);
        vm.stopPrank();

        vm.prank(curator);
        vm.expectRevert(Errors.StrategyInactive.selector);
        campaignRegistry.attachStrategy(id, strategyId);
    }

    function testPauseAndResumeCampaign() public {
        uint64 id = _submitDefaultCampaign();
        vm.prank(admin);
        campaignRegistry.approveCampaign(id);

        vm.prank(curator);
        campaignRegistry.pauseCampaign(id);

        CampaignRegistry.Campaign memory paused = campaignRegistry.getCampaign(id);
        assertEq(uint8(paused.status), uint8(RegistryTypes.CampaignStatus.Paused));

        vm.prank(admin);
        campaignRegistry.resumeCampaign(id);

        CampaignRegistry.Campaign memory active = campaignRegistry.getCampaign(id);
        assertEq(uint8(active.status), uint8(RegistryTypes.CampaignStatus.Active));
    }

    function testCuratorUpdateRequiresAuthorization() public {
        uint64 id = _submitDefaultCampaign();

        vm.prank(curator);
        campaignRegistry.updatePayout(id, makeAddr("newPayout"));

        vm.expectRevert(Errors.UnauthorizedCurator.selector);
        campaignRegistry.updateCurator(id, makeAddr("bad"));
    }

    function testListCampaignIds() public {
        for (uint256 i = 0; i < 3; ++i) {
            vm.deal(address(this), 1 ether);
            campaignRegistry.submitCampaign{value: 0.0001 ether}(
                string.concat("ipfs://", vm.toString(i)),
                curator,
                payout,
                RegistryTypes.LockProfile.Days30
            );
        }

        uint64[] memory ids = campaignRegistry.listCampaignIds(0, 10);
        assertEq(ids.length, 3);
    }
}
