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

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PayoutPreferencesTest is Test {
    ACLManager internal acl;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    PayoutRouter internal router;
    MockERC20 internal token;

    address internal admin = makeAddr("admin");
    address internal vault = makeAddr("vault");
    address internal protocolTreasury = makeAddr("protocolTreasury");
    address internal campaignRecipient = makeAddr("campaignRecipient");
    address internal beneficiary = makeAddr("beneficiary");
    bytes32 internal strategyId;
    bytes32 internal campaignId;

    function setUp() public {
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
        vm.stopPrank();

        _seedStrategyAndCampaign();

        vm.prank(admin);
        router.registerCampaignVault(vault, campaignId);
        vm.prank(admin);
        router.setAuthorizedCaller(vault, true);
    }

    function testSetAndRetrievePreference() public {
        vm.prank(makeAddr("user"));
        router.setVaultPreference(vault, beneficiary, 75);

        GiveTypes.CampaignPreference memory pref = router.getVaultPreference(makeAddr("user"), vault);
        assertEq(pref.beneficiary, beneficiary);
        assertEq(pref.allocationPercentage, 75);
        assertEq(pref.campaignId, campaignId);
    }

    function testDistributionRespectsPreference() public {
        address user = makeAddr("user");

        vm.prank(user);
        router.setVaultPreference(vault, beneficiary, 75);

        vm.prank(vault);
        router.updateUserShares(user, vault, 1_000 ether);

        token.mint(address(router), 1_000 ether);

        vm.prank(vault);
        router.distributeToAllUsers(address(token), 1_000 ether);

        uint256 protocolFee = (1_000 ether * router.PROTOCOL_FEE_BPS()) / 10_000;
        uint256 netYield = 1_000 ether - protocolFee;

        assertEq(token.balanceOf(protocolTreasury), protocolFee);
        assertEq(token.balanceOf(campaignRecipient), (netYield * 75) / 100);
        assertEq(token.balanceOf(beneficiary), netYield - ((netYield * 75) / 100));
    }

    function _seedStrategyAndCampaign() internal {
        strategyId = keccak256("strategy.preferences.test");
        campaignId = keccak256("campaign.preferences.test");

        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: vault,
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
        campaignRegistry.setCampaignVault(campaignId, vault, keccak256("lock.default"));
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
            abi.encodeCall(PayoutRouter.initialize, (address(acl), address(campaignRegistry), admin, protocolTreasury, 250))
        );
        return PayoutRouter(payable(address(proxy)));
    }
}
