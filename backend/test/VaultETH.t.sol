// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/vault/GiveVault4626.sol";
import "../src/donation/NGORegistry.sol";
import "../src/donation/DonationRouter.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "../src/access/RoleManager.sol";

contract VaultETHTest is Test {
    // Core
    GiveVault4626 public vault;
    NGORegistry public registry;
    DonationRouter public router;
    MockWETH public weth;
    MockAdapter public adapter;
    RoleManager public roleManager;

    address public admin;
    address public manager;
    address public user;
    address public feeRecipient;
    address public ngo;

    function setUp() public {
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user = makeAddr("user");
        feeRecipient = makeAddr("fee");
        ngo = makeAddr("ngo");

        // Deploy WETH mock and mint to nobody (we'll wrap through vault)
        weth = new MockWETH();

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), manager);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);

        // Registry + Router
        registry = new NGORegistry(admin);
        router = new DonationRouter(address(roleManager), address(registry), feeRecipient, admin, 250); // 2.5%

        // Vault with WETH as asset
        vault = new GiveVault4626(IERC20(address(weth)), "GIVE WETH", "gvWETH", address(roleManager));

        // Roles and wiring
        vm.startPrank(admin);
        registry.grantRole(registry.NGO_MANAGER_ROLE(), admin);
        registry.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));
        vault.setDonationRouter(address(router));
        vault.setWrappedNative(address(weth));
        router.setAuthorizedCaller(address(vault), true);
        vm.stopPrank();

        // Approve NGO and set as current
        vm.prank(admin);
        registry.addNGO(ngo, "NGO", bytes32("kyc"), admin);
        vm.prank(admin);
        registry.emergencySetCurrentNGO(ngo);

        // Adapter
        adapter = new MockAdapter(IERC20(address(weth)), address(vault));
        vm.prank(manager);
        vault.setActiveAdapter(adapter);

        // Give user ETH
        vm.deal(user, 200 ether);
    }

    function testDepositETH_MintsShares_AndInvestsExcess() public {
        uint256 amount = 10 ether;

        vm.prank(user);
        uint256 shares = vault.depositETH{value: amount}(user, 0);

        // Shares should be proportional to assets
        assertEq(shares, vault.previewDeposit(amount));
        assertEq(vault.totalAssets(), amount);

        // Excess should be invested above buffer
        (uint256 cashBuffer,,,,) = vault.getConfiguration();
        uint256 buffer = (amount * cashBuffer) / 10_000;
        assertEq(weth.balanceOf(address(vault)), buffer);
        assertEq(adapter.invested(), amount - buffer);
    }

    function testRedeemETH_UnwrapsAndSendsETH() public {
        uint256 amount = 5 ether;
        vm.prank(user);
        uint256 shares = vault.depositETH{value: amount}(user, 0);

        // Redeem all
        uint256 userBefore = user.balance;
        vm.prank(user);
        uint256 assets = vault.redeemETH(shares, user, user, 0);

        assertApproxEqAbs(assets, amount, 1); // allow rounding
        assertEq(user.balance, userBefore + assets);
        assertEq(vault.totalSupply(), 0);
    }
}

// Minimal WETH mock with deposit/withdraw
contract MockWETH is ERC20("Wrapped Ether", "WETH") {
    constructor() {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");
    }
}

// IYieldAdapter mock compatible with vault flows
contract MockAdapter is IYieldAdapter {
    IERC20 public override asset;
    address public override vault;

    uint256 public investedAmount;
    uint256 public pendingProfit;

    constructor(IERC20 _asset, address _vault) {
        asset = _asset;
        vault = _vault;
    }

    function totalAssets() external view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function invest(uint256 assets) external override {
        require(msg.sender == vault, "Only vault");
        investedAmount += assets;
        emit Invested(assets);
    }

    function divest(uint256 assets) external override returns (uint256 returned) {
        require(msg.sender == vault, "Only vault");
        uint256 bal = asset.balanceOf(address(this));
        returned = assets > bal ? bal : assets;
        if (returned > 0) {
            asset.transfer(vault, returned);
        }
        if (returned <= investedAmount) {
            investedAmount -= returned;
        } else {
            investedAmount = 0;
        }
        emit Divested(assets, returned);
    }

    function harvest() external override returns (uint256 profit, uint256 loss) {
        require(msg.sender == vault, "Only vault");
        uint256 bal = asset.balanceOf(address(this));
        uint256 principal = investedAmount;
        uint256 availableProfit = bal > principal ? bal - principal : 0;
        profit = pendingProfit > availableProfit ? availableProfit : pendingProfit;
        if (profit > 0) {
            asset.transfer(vault, profit);
            pendingProfit -= profit;
        }
        loss = 0;
        emit Harvested(profit, 0);
    }

    function emergencyWithdraw() external override returns (uint256 returned) {
        uint256 bal = asset.balanceOf(address(this));
        if (bal > 0) asset.transfer(vault, bal);
        investedAmount = 0;
        emit EmergencyWithdraw(bal);
        return bal;
    }

    // Expose invested for assertions
    function invested() external view returns (uint256) {
        return investedAmount;
    }
}
