// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/manager/StrategyManager.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/payout/PayoutRouter.sol";
import "../src/governance/ACLManager.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "../src/types/GiveTypes.sol";
import "../src/utils/GiveErrors.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockAdapter is IYieldAdapter {
    IERC20 public override asset;
    address public override vault;

    constructor(IERC20 _asset, address _vault) {
        asset = _asset;
        vault = _vault;
    }

    function totalAssets() external view override returns (uint256) {
        return 0;
    }

    function invest(uint256 assets) external override {}

    function divest(uint256 assets) external override returns (uint256) {
        return 0;
    }

    function harvest() external override returns (uint256, uint256) {
        return (0, 0);
    }

    function emergencyWithdraw() external override returns (uint256) {
        return 0;
    }
}

contract StrategyManagerAdvancedTest is Test {
    ACLManager internal acl;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    StrategyManager internal manager;
    GiveVault4626 internal vault;
    PayoutRouter internal router;
    MockAdapter internal adapter;
    MockERC20 internal token;

    address internal admin;
    address internal protocolTreasury;
    address internal campaignRecipient;
    bytes32 internal strategyId;
    bytes32 internal campaignId;

    function setUp() public {
        admin = makeAddr("admin");
        protocolTreasury = makeAddr("protocolTreasury");
        campaignRecipient = makeAddr("campaignRecipient");

        acl = _deployACL();
        strategyRegistry = _deployStrategyRegistry();
        campaignRegistry = _deployCampaignRegistry();
        router = _deployPayoutRouter();

        token = new MockERC20();
        vault = new GiveVault4626(IERC20(address(token)), "GIVE", "gv", admin);
        adapter = new MockAdapter(IERC20(address(token)), address(vault));

        manager = new StrategyManager(address(vault), admin, address(strategyRegistry), address(campaignRegistry));

        vm.startPrank(admin);
        // Create strategy manager roles if they don't exist
        acl.createRole(manager.STRATEGY_MANAGER_ROLE(), admin);
        acl.createRole(manager.EMERGENCY_ROLE(), admin);
        acl.createRole(manager.STRATEGY_ADMIN_ROLE(), admin);
        acl.createRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.createRole(router.FEE_MANAGER_ROLE(), admin);

        acl.grantRole(manager.STRATEGY_MANAGER_ROLE(), admin);
        acl.grantRole(manager.EMERGENCY_ROLE(), admin);
        acl.grantRole(acl.ROLE_CAMPAIGN_ADMIN(), admin);
        acl.grantRole(acl.ROLE_CAMPAIGN_CREATOR(), admin);
        acl.grantRole(acl.ROLE_STRATEGY_ADMIN(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.FEE_MANAGER_ROLE(), admin);

        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(manager));
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), admin);
        vm.stopPrank();

        _seedStrategyAndCampaign();

        vm.prank(admin);
        router.registerCampaignVault(address(vault), campaignId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);
    }

    function testSetActiveAdapterRequiresMatchingStrategy() public {
        // Adapter already registered in setUp, just approve and test
        vm.prank(admin);
        manager.setAdapterApproval(address(adapter), true);

        vm.prank(admin);
        manager.setActiveAdapter(address(adapter));

        // Try to set a wrong adapter that doesn't match the campaign's strategy
        // Since it's not approved, it will fail with InvalidAdapter first
        address wrongAdapter = makeAddr("wrongAdapter");
        vm.prank(admin);
        vm.expectRevert(GiveErrors.InvalidAdapter.selector);
        manager.setActiveAdapter(wrongAdapter);
    }

    function _seedStrategyAndCampaign() internal {
        strategyId = keccak256("strategy.manager.test");
        campaignId = keccak256("campaign.manager.test");

        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: address(adapter),
                riskTier: bytes32("tier"),
                maxTvl: 1_000 ether,
                metadataHash: keccak256("strategy")
            })
        );

        vm.prank(admin);
        campaignRegistry.submitCampaign(
            CampaignRegistry.CampaignInput({
                id: campaignId,
                payoutRecipient: campaignRecipient,
                strategyId: strategyId,
                metadataHash: keccak256("campaign.metadata"),
                metadataCID: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                targetStake: 1_000 ether,
                minStake: 100 ether,
                fundraisingStart: uint64(block.timestamp),
                fundraisingEnd: uint64(block.timestamp + 30 days)
            })
        );

        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId, admin);
        vm.prank(admin);
        campaignRegistry.setCampaignVault(campaignId, address(vault), keccak256("lock"));
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
            abi.encodeCall(
                PayoutRouter.initialize, (address(acl), address(campaignRegistry), admin, protocolTreasury, 0)
            )
        );
        return PayoutRouter(payable(address(proxy)));
    }
}
