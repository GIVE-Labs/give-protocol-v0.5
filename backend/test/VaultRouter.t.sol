// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/donation/NGORegistry.sol";
import "../src/donation/DonationRouter.sol";
import "../src/interfaces/IYieldAdapter.sol";

contract VaultRouterTest is Test {
    // Core
    GiveVault4626 public vault;
    NGORegistry public registry;
    DonationRouter public router;
    MockERC20 public usdc;
    MockAdapter public adapter;

    address public admin;
    address public manager;
    address public user;
    address public feeRecipient;
    address public ngo;

    function setUp() public {
        // Addresses
        admin = makeAddr("admin");
        manager = makeAddr("manager");
        user = makeAddr("user");
        feeRecipient = makeAddr("fee");
        ngo = makeAddr("ngo");

        // Token
        usdc = new MockERC20("Test USDC", "TUSDC", 6);
        usdc.mint(user, 1_000_000e6);

        // Registry + Router
        registry = new NGORegistry(admin);
        router = new DonationRouter(admin, address(registry), feeRecipient, admin, 250); // 2.5%

        // Vault
        vault = new GiveVault4626(IERC20(address(usdc)), "GIVE USDC", "gvUSDC", admin);

        // Roles and wiring
        vm.startPrank(admin);
        registry.grantRole(registry.NGO_MANAGER_ROLE(), admin);
        registry.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), manager);
        vault.setDonationRouter(address(router));
        router.setAuthorizedCaller(address(vault), true);
        vm.stopPrank();

        // Approve NGO and set as current
        vm.prank(admin);
        registry.addNGO(ngo, "NGO", bytes32("kyc"), admin);

        // Ensure NGO is set as current (should happen automatically in addNGO)
        vm.prank(admin);
        registry.emergencySetCurrentNGO(ngo);

        // Adapter
        adapter = new MockAdapter(IERC20(address(usdc)), address(vault));
        vm.prank(manager);
        vault.setActiveAdapter(adapter);
    }

    function testDepositInvestsExcessAboveBuffer() public {
        uint256 amount = 10_000e6;
        vm.startPrank(user);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();

        (uint256 cashBuffer,,,,) = vault.getConfiguration();
        uint256 buffer = (amount * cashBuffer) / 10_000;
        assertEq(usdc.balanceOf(address(vault)), buffer);
        assertEq(adapter.invested(), amount - buffer);
        assertEq(vault.totalAssets(), amount);
    }

    function testHarvestRoutesToRouterAndDonates() public {
        uint256 amount = 10_000e6;
        vm.startPrank(user);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, user);

        // Set user preference to donate to NGO
        router.setUserPreference(ngo, 100); // 100% to NGO
        vm.stopPrank();

        // Fund adapter with profit and mark it as pending
        uint256 profit = 1_000e6;
        usdc.mint(address(adapter), profit);
        vm.prank(admin);
        adapter.mockAddProfit(profit);

        uint256 ngoBefore = usdc.balanceOf(ngo);
        uint256 adminBefore = usdc.balanceOf(admin); // Protocol treasury

        (uint256 p, uint256 l) = vault.harvest();
        assertEq(p, profit);
        assertEq(l, 0);

        uint256 expectedProtocolFee = (profit * 250) / 10_000; // 2.5% protocol fee
        uint256 expectedDonation = profit - expectedProtocolFee;

        assertEq(usdc.balanceOf(ngo), ngoBefore + expectedDonation);
        assertEq(usdc.balanceOf(admin), adminBefore + expectedProtocolFee); // Protocol fee goes to admin
    }

    function testWithdrawReturnsPrincipal() public {
        uint256 amount = 5_000e6;
        vm.startPrank(user);
        usdc.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, user);
        uint256 withdrawn = vault.redeem(shares, user, user);
        vm.stopPrank();

        assertApproxEqAbs(withdrawn, amount, 1);
    }
}

// Minimal ERC20
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_, uint8 d) ERC20(name_, symbol_) {
        _decimals = d;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
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
        uint256 bal = asset.balanceOf(address(this));
        return bal; // simplistic view
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

    // Testing helper
    function mockAddProfit(uint256 amount) external {
        pendingProfit += amount;
    }

    // Expose invested for assertions
    function invested() external view returns (uint256) {
        return investedAmount;
    }
}
