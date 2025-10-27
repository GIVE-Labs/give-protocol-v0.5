// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/vault/GiveVault4626.sol";
import "../src/payout/PayoutRouter.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/governance/ACLManager.sol";
import "../src/interfaces/IYieldAdapter.sol";

contract VaultETHTest is Test {
    GiveVault4626 public vault;
    PayoutRouter public router;
    StrategyRegistry public strategyRegistry;
    CampaignRegistry public campaignRegistry;
    MockWETH public weth;
    MockAdapter public adapter;

    address public admin;
    address public manager;
    address public user;
    address public protocolTreasury;
    address public campaignRecipient;
    address public beneficiary;
    bytes32 public strategyId;
    bytes32 public campaignId;

    function setUp() public {
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user = makeAddr("user");
        protocolTreasury = makeAddr("protocolTreasury");
        campaignRecipient = makeAddr("campaignRecipient");
        beneficiary = makeAddr("beneficiary");

        ACLManager acl = _deployACL();
        strategyRegistry = _deployStrategyRegistry(acl);
        campaignRegistry = _deployCampaignRegistry(acl);
        router = _deployPayoutRouter(acl);

        weth = new MockWETH();
        vault = new GiveVault4626(
            IERC20(address(weth)),
            "GIVE WETH",
            "gvWETH",
            admin
        );
        adapter = new MockAdapter(IERC20(address(weth)), address(vault));

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

        _seedStrategyAndCampaign(admin);

        vm.prank(admin);
        router.registerCampaignVault(address(vault), campaignId);
        vm.prank(admin);
        router.setAuthorizedCaller(address(vault), true);
        vm.prank(admin);
        campaignRegistry.setCampaignVault(
            campaignId,
            address(vault),
            keccak256("lock")
        );

        vm.prank(manager);
        vault.setDonationRouter(address(router));
        vm.prank(manager);
        vault.setWrappedNative(address(weth));
        vm.prank(manager);
        vault.setActiveAdapter(adapter);

        vm.deal(user, 100 ether);
    }

    function testDepositETHMintsSharesAndInvestsExcess() public {
        uint256 amount = 10 ether;

        vm.prank(user);
        uint256 shares = vault.depositETH{value: amount}(user, 0);

        assertEq(shares, vault.previewDeposit(amount));
        assertEq(vault.totalAssets(), amount);

        (uint256 cashBuffer, , , , ) = vault.getConfiguration();
        uint256 buffer = (amount * cashBuffer) / 10_000;
        assertEq(weth.balanceOf(address(vault)), buffer);
        assertEq(adapter.investedAmount(), amount - buffer);
    }

    function testRedeemETHUnwrapsAndSendsETH() public {
        uint256 amount = 5 ether;
        vm.prank(user);
        uint256 shares = vault.depositETH{value: amount}(user, 0);

        uint256 beforeBal = user.balance;
        vm.prank(user);
        uint256 assets = vault.redeemETH(shares, user, user, 0);

        assertApproxEqAbs(assets, amount, 1);
        assertEq(user.balance, beforeBal + assets);
    }

    function testHarvestDistributesToCampaignAndBeneficiary() public {
        vm.prank(user);
        vault.depositETH{value: 20 ether}(user, 0);

        vm.prank(user);
        router.setVaultPreference(address(vault), beneficiary, 50);

        weth.mint(address(adapter), 2 ether);
        adapter.setPendingProfit(2 ether);

        vm.prank(manager);
        (uint256 profit, ) = vault.harvest();
        assertEq(profit, 2 ether);

        uint256 protocolFee = (profit * router.PROTOCOL_FEE_BPS()) / 10_000;
        uint256 netYield = profit - protocolFee;

        assertEq(weth.balanceOf(protocolTreasury), protocolFee);
        assertEq(weth.balanceOf(campaignRecipient), (netYield * 50) / 100);
        assertEq(
            weth.balanceOf(beneficiary),
            netYield - ((netYield * 50) / 100)
        );
    }

    function _seedStrategyAndCampaign(address grantor) internal {
        strategyId = keccak256("strategy.vaulteth.test");
        campaignId = keccak256("campaign.vaulteth.test");

        vm.prank(grantor);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: address(adapter),
                riskTier: bytes32("tier"),
                maxTvl: 1_000_000 ether,
                metadataHash: keccak256("strategy")
            })
        );

        vm.deal(grantor, 1 ether);
        vm.prank(grantor);
        campaignRegistry.submitCampaign{value: 0.005 ether}(
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

        vm.prank(grantor);
        campaignRegistry.approveCampaign(campaignId, grantor);
    }

    function _deployACL() internal returns (ACLManager) {
        ACLManager impl = new ACLManager();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(ACLManager.initialize, (admin, admin))
        );
        return ACLManager(address(proxy));
    }

    function _deployStrategyRegistry(
        ACLManager acl
    ) internal returns (StrategyRegistry) {
        StrategyRegistry impl = new StrategyRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(StrategyRegistry.initialize, (address(acl)))
        );
        return StrategyRegistry(address(proxy));
    }

    function _deployCampaignRegistry(
        ACLManager acl
    ) internal returns (CampaignRegistry) {
        CampaignRegistry impl = new CampaignRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(
                CampaignRegistry.initialize,
                (address(acl), address(strategyRegistry))
            )
        );
        return CampaignRegistry(address(proxy));
    }

    function _deployPayoutRouter(
        ACLManager acl
    ) internal returns (PayoutRouter) {
        PayoutRouter impl = new PayoutRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(
                PayoutRouter.initialize,
                (
                    address(acl),
                    address(campaignRegistry),
                    admin,
                    protocolTreasury,
                    250
                )
            )
        );
        return PayoutRouter(payable(address(proxy)));
    }
}

contract MockWETH is ERC20("Wrapped Ether", "WETH") {
    constructor() {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");
    }
}

contract MockAdapter is IYieldAdapter {
    IERC20 public override asset;
    address public override vault;
    uint256 public invested;
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
        invested += assets;
        emit Invested(assets);
    }

    function divest(
        uint256 assets
    ) external override returns (uint256 returned) {
        require(msg.sender == vault, "only vault");
        uint256 bal = asset.balanceOf(address(this));
        returned = assets > bal ? bal : assets;
        if (returned > 0) {
            asset.transfer(vault, returned);
        }
        invested = returned >= invested ? 0 : invested - returned;
        emit Divested(assets, returned);
    }

    function harvest()
        external
        override
        returns (uint256 profit, uint256 loss)
    {
        require(msg.sender == vault, "only vault");
        uint256 bal = asset.balanceOf(address(this));
        uint256 principal = invested;
        uint256 availableProfit = bal > principal ? bal - principal : 0;
        profit = availableProfit > pendingProfit
            ? pendingProfit
            : availableProfit;
        if (profit > 0) {
            asset.transfer(vault, profit);
            pendingProfit -= profit;
        }
        loss = 0;
        emit Harvested(profit, loss);
    }

    function emergencyWithdraw() external override returns (uint256 returned) {
        returned = asset.balanceOf(address(this));
        if (returned > 0) {
            asset.transfer(vault, returned);
        }
        invested = 0;
        emit EmergencyWithdraw(returned);
    }

    function investedAmount() external view returns (uint256) {
        return invested;
    }

    function setPendingProfit(uint256 amount) external {
        pendingProfit = amount;
    }
}
