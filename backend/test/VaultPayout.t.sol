// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/vault/GiveVault4626.sol";
import "../src/payout/PayoutRouter.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/governance/ACLManager.sol";
import "../src/interfaces/IYieldAdapter.sol";

contract VaultPayoutTest is Test {
    GiveVault4626 internal vault;
    PayoutRouter internal router;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    MockERC20 internal token;
    MockAdapter internal adapter;

    address internal admin = makeAddr("admin");
    address internal manager = makeAddr("manager");
    address internal user = makeAddr("user");
    address internal protocolTreasury = makeAddr("protocolTreasury");
    address internal campaignRecipient = makeAddr("campaignRecipient");
    address internal beneficiary = makeAddr("beneficiary");
    bytes32 internal strategyId;
    bytes32 internal campaignId;

    function setUp() public {
        ACLManager acl = _deployACL();
        strategyRegistry = _deployStrategyRegistry(acl);
        campaignRegistry = _deployCampaignRegistry(acl);
        router = _deployPayoutRouter(acl);

        token = new MockERC20();
        vault = new GiveVault4626(IERC20(address(token)), "GIVE", "gv", admin);
        adapter = new MockAdapter(IERC20(address(token)), address(vault));

        vm.startPrank(admin);
        acl.createRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.createRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(acl.campaignAdminRole(), admin);
        acl.grantRole(acl.campaignCreatorRole(), admin);
        acl.grantRole(acl.strategyAdminRole(), admin);
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), manager);
        vm.stopPrank();

        _seedStrategyAndCampaign(acl);

        vm.prank(admin);
        router.registerCampaignVault(address(vault), campaignId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);
        vm.prank(admin);
        campaignRegistry.setCampaignVault(campaignId, address(vault), keccak256("lock"));

        vm.prank(manager);
        vault.setDonationRouter(address(router));
        vm.prank(manager);
        vault.setActiveAdapter(adapter);
    }

    function testHarvestRoutesYieldCorrectly() public {
        token.mint(user, 1_000 ether);
        vm.startPrank(user);
        token.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, user);
        vm.stopPrank();

        vm.prank(user);
        router.setVaultPreference(address(vault), beneficiary, 50);

        token.mint(address(adapter), 100 ether);
        adapter.setPendingProfit(100 ether);

        vm.prank(manager);
        (uint256 profit,) = vault.harvest();
        assertEq(profit, 100 ether);

        uint256 protocolFee = (profit * router.PROTOCOL_FEE_BPS()) / 10_000;
        uint256 netYield = profit - protocolFee;

        assertEq(token.balanceOf(protocolTreasury), protocolFee);
        assertEq(token.balanceOf(campaignRecipient), netYield / 2);
        assertEq(token.balanceOf(beneficiary), netYield / 2);
    }

    function _seedStrategyAndCampaign(ACLManager acl) internal {
        strategyId = keccak256("strategy.vaultpayout.test");
        campaignId = keccak256("campaign.vaultpayout.test");

        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: address(adapter),
                riskTier: bytes32("tier"),
                maxTvl: 1_000_000 ether,
                metadataHash: keccak256("strategy")
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
    }

    function _deployACL() internal returns (ACLManager) {
        ACLManager impl = new ACLManager();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ACLManager.initialize, (admin, admin)));
        return ACLManager(address(proxy));
    }

    function _deployStrategyRegistry(ACLManager acl) internal returns (StrategyRegistry) {
        StrategyRegistry impl = new StrategyRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(StrategyRegistry.initialize, (address(acl))));
        return StrategyRegistry(address(proxy));
    }

    function _deployCampaignRegistry(ACLManager acl) internal returns (CampaignRegistry) {
        CampaignRegistry impl = new CampaignRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(CampaignRegistry.initialize, (address(acl), address(strategyRegistry)))
        );
        return CampaignRegistry(address(proxy));
    }

    function _deployPayoutRouter(ACLManager acl) internal returns (PayoutRouter) {
        PayoutRouter impl = new PayoutRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(PayoutRouter.initialize, (address(acl), address(campaignRegistry), admin, protocolTreasury, 250))
        );
        return PayoutRouter(payable(address(proxy)));
    }
}

contract MockERC20 is ERC20("Mock Token", "MCK") {
    constructor() {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

contract MockAdapter is IYieldAdapter {
    IERC20 public override asset;
    address public override vault;
    uint256 public pendingProfit;

    constructor(IERC20 asset_, address vault_) {
        asset = asset_;
        vault = vault_;
    }

    function totalAssets() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function invest(uint256 assets) external override {
        require(msg.sender == vault, "only vault");
        emit Invested(assets);
    }

    function divest(uint256 assets) external override returns (uint256 returned) {
        require(msg.sender == vault, "only vault");
        uint256 bal = asset.balanceOf(address(this));
        returned = assets > bal ? bal : assets;
        if (returned > 0) {
            asset.transfer(vault, returned);
        }
        emit Divested(assets, returned);
    }

    function harvest() external override returns (uint256 profit, uint256 loss) {
        require(msg.sender == vault, "only vault");
        profit = pendingProfit;
        if (profit > 0) {
            asset.transfer(vault, profit);
            pendingProfit = 0;
        }
        loss = 0;
        emit Harvested(profit, loss);
    }

    function emergencyWithdraw() external override returns (uint256 returned) {
        returned = asset.balanceOf(address(this));
        if (returned > 0) asset.transfer(vault, returned);
        emit EmergencyWithdraw(returned);
    }

    function setPendingProfit(uint256 amount) external {
        pendingProfit = amount;
    }
}
