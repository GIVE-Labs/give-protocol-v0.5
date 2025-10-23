// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/payout/PayoutRouter.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/governance/ACLManager.sol";
import "../src/types/GiveTypes.sol";
import "../src/utils/Errors.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PayoutRouterTest is Test {
    ACLManager internal acl;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal router;
    MockERC20 internal token;

    address internal admin;
    address internal campaignVault;
    address internal campaignRecipient;
    address internal protocolTreasury;
    bytes32 internal strategyId;
    bytes32 internal campaignId;

    function setUp() public {
        admin = makeAddr("admin");
        campaignVault = makeAddr("vault");
        campaignRecipient = makeAddr("campaignRecipient");
        protocolTreasury = makeAddr("protocolTreasury");

        acl = _deployACL();
        strategyRegistry = _deployStrategyRegistry();
        campaignRegistry = _deployCampaignRegistry();
        router = _deployPayoutRouter();

        token = new MockERC20();

        vm.startPrank(admin);
        acl.createRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.createRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(acl.campaignAdminRole(), admin);
        acl.grantRole(acl.campaignCreatorRole(), admin);
        acl.grantRole(acl.strategyAdminRole(), admin);
        acl.grantRole(acl.campaignCuratorRole(), admin);
        acl.grantRole(acl.checkpointCouncilRole(), admin);
        vm.stopPrank();

        _seedStrategyAndCampaign();

        vm.prank(admin);
        router.registerCampaignVault(campaignVault, campaignId);
        vm.prank(admin);
        router.setAuthorizedCaller(campaignVault, true);
    }

    function testUpdateFeeConfig() public {
        address newRecipient = makeAddr("feeRecipient");
        vm.prank(admin);
        router.updateFeeConfig(newRecipient, 150);
        assertEq(router.feeRecipient(), newRecipient);
        assertEq(router.feeBps(), 150);
    }

    function testDistributeDefaultsToCampaign() public {
        address user = makeAddr("user");

        vm.prank(campaignVault);
        router.updateUserShares(user, campaignVault, 1_000);

        token.mint(address(router), 1_000 ether);

        vm.prank(campaignVault);
        uint256 distributed = router.distributeToAllUsers(address(token), 1_000 ether);

        uint256 protocolFee = (1_000 ether * router.PROTOCOL_FEE_BPS()) / 10_000;
        uint256 netYield = 1_000 ether - protocolFee;

        assertEq(distributed, 1_000 ether);
        assertEq(token.balanceOf(campaignRecipient), netYield);
        assertEq(token.balanceOf(protocolTreasury), protocolFee);
    }

    function testUnauthorizedCallerCannotDistribute() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, address(this)));
        router.distributeToAllUsers(address(token), 100 ether);
    }

    function testDistributeHaltsWhenCampaignFailed() public {
        address supporter = makeAddr("supporter");

        vm.prank(admin);
        campaignRegistry.setCampaignStatus(campaignId, GiveTypes.CampaignStatus.Active);

        vm.prank(campaignVault);
        router.updateUserShares(supporter, campaignVault, 1_000);

        vm.prank(admin);
        campaignRegistry.recordStakeDeposit(campaignId, supporter, 1_000 ether);

        CampaignRegistry.CheckpointInput memory input = CampaignRegistry.CheckpointInput({
            windowStart: uint64(block.timestamp),
            windowEnd: uint64(block.timestamp + 1 days),
            executionDeadline: uint64(block.timestamp + 2 days),
            quorumBps: 5_000
        });

        vm.prank(admin);
        uint256 checkpointId = campaignRegistry.scheduleCheckpoint(campaignId, input);

        vm.prank(admin);
        campaignRegistry.updateCheckpointStatus(campaignId, checkpointId, GiveTypes.CheckpointStatus.Voting);

        vm.prank(supporter);
        campaignRegistry.voteOnCheckpoint(campaignId, checkpointId, false);

        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(admin);
        campaignRegistry.finalizeCheckpoint(campaignId, checkpointId);

        token.mint(address(router), 500 ether);
        vm.prank(campaignVault);
        vm.expectRevert(abi.encodeWithSelector(Errors.OperationNotAllowed.selector));
        router.distributeToAllUsers(address(token), 500 ether);
    }

    function _seedStrategyAndCampaign() internal {
        strategyId = keccak256("strategy.router.test");
        campaignId = keccak256("campaign.router.test");

        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: campaignVault,
                riskTier: bytes32("tier"),
                maxTvl: 1_000_000 ether,
                metadataHash: keccak256("metadata")
            })
        );

        vm.prank(admin);
        campaignRegistry.submitCampaign(
            CampaignRegistry.CampaignInput({
                id: campaignId,
                payoutRecipient: campaignRecipient,
                strategyId: strategyId,
                metadataHash: keccak256("campaign"),
                targetStake: 1_000 ether,
                minStake: 100 ether,
                fundraisingStart: uint64(block.timestamp),
                fundraisingEnd: uint64(block.timestamp + 30 days)
            })
        );

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId, admin);

        vm.prank(admin);
        campaignRegistry.setCampaignVault(campaignId, campaignVault, keccak256("lock.default"));
    }

    function _deployACL() internal returns (ACLManager) {
        ACLManager impl = new ACLManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ACLManager.initialize, (admin, admin)));
        return ACLManager(address(proxy));
    }

    function _deployStrategyRegistry() internal returns (StrategyRegistry) {
        StrategyRegistry impl = new StrategyRegistry();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeCall(StrategyRegistry.initialize, (address(acl))));
        return StrategyRegistry(address(proxy));
    }

    function _deployCampaignRegistry() internal returns (CampaignRegistry) {
        CampaignRegistry impl = new CampaignRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(CampaignRegistry.initialize, (address(acl), address(strategyRegistry)))
        );
        return CampaignRegistry(address(proxy));
    }

    function _deployPayoutRouter() internal returns (PayoutRouter) {
        PayoutRouter impl = new PayoutRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(PayoutRouter.initialize, (address(acl), address(campaignRegistry), admin, protocolTreasury, 0))
        );
        return PayoutRouter(payable(address(proxy)));
    }
}
