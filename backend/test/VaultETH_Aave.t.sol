// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/vault/GiveVault4626.sol";
import "../src/donation/NGORegistry.sol";
import "../src/donation/DonationRouter.sol";
import "../src/adapters/AaveAdapter.sol";
import "../src/interfaces/IYieldAdapter.sol";
import "../src/manager/StrategyManager.sol";
import "../src/interfaces/IWETH.sol";

/**
 * @title VaultETH_AaveTest
 * @dev Comprehensive test suite for ETH vault with Aave adapter integration
 * @notice Tests all aspects of ETH staking, WETH conversion, Aave yield generation, and donation routing
 */
contract VaultETH_AaveTest is Test {
    // Core contracts
    GiveVault4626 public ethVault;
    NGORegistry public registry;
    DonationRouter public router;
    StrategyManager public manager;
    MockWETH public weth;
    AaveAdapter public aaveAdapter;
    MockAavePool public aavePool;
    MockAToken public aWETH;

    // Test addresses
    address public admin;
    address public vaultManager;
    address public user1;
    address public user2;
    address public feeRecipient;
    address public ngo1;
    address public ngo2;

    // Test constants
    uint256 public constant INITIAL_ETH_BALANCE = 1000 ether;
    uint256 public constant CASH_BUFFER_BPS = 100; // 1%
    uint256 public constant SLIPPAGE_BPS = 50; // 0.5%
    uint256 public constant MAX_LOSS_BPS = 50; // 0.5%
    uint256 public constant FEE_BPS = 250; // 2.5%

    event ETHDeposited(address indexed user, uint256 amount, uint256 shares);
    event ETHWithdrawn(address indexed user, uint256 amount, uint256 shares);
    event YieldHarvested(uint256 profit, uint256 loss, uint256 donated);

    function setUp() public {
        // Setup test addresses
        admin = makeAddr("admin");
        vaultManager = makeAddr("vaultManager");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        feeRecipient = makeAddr("feeRecipient");
        ngo1 = makeAddr("ngo1");
        ngo2 = makeAddr("ngo2");

        // Deploy WETH mock
        weth = new MockWETH();

        // Deploy Aave mocks
        aWETH = new MockAToken("Aave WETH", "aWETH", 18, address(weth));
        aavePool = new MockAavePool(address(weth), address(aWETH));

        // Deploy core contracts
        registry = new NGORegistry(admin);
        router = new DonationRouter(admin, address(registry), feeRecipient, admin, FEE_BPS);

        // Deploy ETH vault with WETH as underlying asset
        ethVault = new GiveVault4626(IERC20(address(weth)), "GIVE ETH Vault", "gvETH", admin);

        // Deploy strategy manager
        manager = new StrategyManager(address(ethVault), admin);

        // Deploy Aave adapter for WETH
        vm.prank(admin);
        aaveAdapter = new AaveAdapter(address(weth), address(ethVault), address(aavePool), admin);

        // Setup roles and permissions
        vm.startPrank(admin);
        registry.grantRole(registry.NGO_MANAGER_ROLE(), admin);
        registry.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));
        ethVault.grantRole(ethVault.VAULT_MANAGER_ROLE(), vaultManager);
        ethVault.grantRole(ethVault.VAULT_MANAGER_ROLE(), address(manager));
        ethVault.setDonationRouter(address(router));
        ethVault.setWrappedNative(address(weth));
        router.setAuthorizedCaller(address(ethVault), true);

        // Configure strategy manager
        manager.setAdapterApproval(address(aaveAdapter), true);
        manager.setActiveAdapter(address(aaveAdapter));
        manager.updateVaultParameters(CASH_BUFFER_BPS, SLIPPAGE_BPS, MAX_LOSS_BPS);
        manager.setDonationRouter(address(router));
        vm.stopPrank();

        // Register and approve NGOs
        vm.startPrank(admin);
        registry.addNGO(ngo1, "Education NGO", bytes32("kyc1"), admin);
        registry.addNGO(ngo2, "Health NGO", bytes32("kyc2"), admin);
        registry.emergencySetCurrentNGO(ngo1);
        vm.stopPrank();

        // Give users ETH
        vm.deal(user1, INITIAL_ETH_BALANCE);
        vm.deal(user2, INITIAL_ETH_BALANCE);
    }

    // ============ Basic ETH Deposit/Withdraw Tests ============

    function testDepositETH_BasicFlow() public {
        uint256 depositAmount = 10 ether;

        vm.prank(user1);
        uint256 shares = ethVault.depositETH{value: depositAmount}(user1, 0);

        // Verify shares minted
        assertEq(shares, ethVault.previewDeposit(depositAmount));
        assertEq(ethVault.balanceOf(user1), shares);
        assertEq(ethVault.totalAssets(), depositAmount);

        // Verify WETH was minted and excess invested
        uint256 expectedBuffer = (depositAmount * CASH_BUFFER_BPS) / 10_000;
        assertEq(weth.balanceOf(address(ethVault)), expectedBuffer);
        assertEq(aWETH.balanceOf(address(aaveAdapter)), depositAmount - expectedBuffer);
    }

    function testRedeemETH_BasicFlow() public {
        uint256 depositAmount = 5 ether;

        // First deposit
        vm.prank(user1);
        uint256 shares = ethVault.depositETH{value: depositAmount}(user1, 0);

        // Then redeem
        uint256 userBalanceBefore = user1.balance;
        vm.prank(user1);
        uint256 assets = ethVault.redeemETH(shares, user1, user1, 0);

        // Verify ETH returned
        assertApproxEqAbs(assets, depositAmount, 1); // Allow 1 wei rounding
        assertEq(user1.balance, userBalanceBefore + assets);
        assertEq(ethVault.totalSupply(), 0);
        assertEq(ethVault.balanceOf(user1), 0);
    }

    function testWithdrawETH_BasicFlow() public {
        uint256 depositAmount = 8 ether;
        uint256 withdrawAmount = 3 ether;

        // Deposit first
        vm.prank(user1);
        ethVault.depositETH{value: depositAmount}(user1, 0);

        // Withdraw specific amount
        uint256 userBalanceBefore = user1.balance;
        vm.prank(user1);
        uint256 shares = ethVault.withdrawETH(withdrawAmount, user1, user1, type(uint256).max);

        // Verify withdrawal
        assertEq(user1.balance, userBalanceBefore + withdrawAmount);
        assertApproxEqAbs(ethVault.totalAssets(), depositAmount - withdrawAmount, 1);
        assertGt(ethVault.balanceOf(user1), 0); // Should still have remaining shares
    }

    // ============ Aave Integration Tests ============

    function testAaveIntegration_InvestAndDivest() public {
        uint256 depositAmount = 20 ether;

        vm.prank(user1);
        ethVault.depositETH{value: depositAmount}(user1, 0);

        // Verify investment in Aave
        uint256 expectedInvested = depositAmount - (depositAmount * CASH_BUFFER_BPS) / 10_000;
        assertEq(aWETH.balanceOf(address(aaveAdapter)), expectedInvested);
        assertEq(aaveAdapter.totalAssets(), expectedInvested);

        // Simulate yield accrual in Aave by minting aTokens to adapter
        uint256 yieldAmount = 1 ether;
        aWETH.mint(address(aaveAdapter), yieldAmount);

        // Harvest yield
        vm.prank(vaultManager);
        (uint256 profit, uint256 loss) = ethVault.harvest();

        assertEq(profit, yieldAmount);
        assertEq(loss, 0);
        // Router distributes funds immediately, check feeRecipient received the donation
        uint256 expectedDonation = yieldAmount - (yieldAmount * 250) / 10_000; // Subtract 2.5% protocol fee
        assertEq(weth.balanceOf(feeRecipient), expectedDonation);
    }

    function testAaveAdapter_EmergencyWithdraw() public {
        uint256 depositAmount = 15 ether;

        vm.prank(user1);
        ethVault.depositETH{value: depositAmount}(user1, 0);

        // Emergency withdraw from adapter
        vm.prank(admin);
        uint256 withdrawn = ethVault.emergencyWithdrawFromAdapter();

        assertGt(withdrawn, 0);
        assertEq(aWETH.balanceOf(address(aaveAdapter)), 0);
        assertGt(weth.balanceOf(address(ethVault)), 0);
    }

    // ============ Multi-User Scenarios ============

    function testMultiUser_DepositAndWithdraw() public {
        uint256 deposit1 = 10 ether;
        uint256 deposit2 = 15 ether;

        // User1 deposits
        vm.prank(user1);
        uint256 shares1 = ethVault.depositETH{value: deposit1}(user1, 0);

        // User2 deposits
        vm.prank(user2);
        uint256 shares2 = ethVault.depositETH{value: deposit2}(user2, 0);

        // Verify proportional shares
        assertEq(ethVault.totalAssets(), deposit1 + deposit2);
        assertEq(ethVault.balanceOf(user1), shares1);
        assertEq(ethVault.balanceOf(user2), shares2);

        // Both users withdraw
        vm.prank(user1);
        uint256 assets1 = ethVault.redeemETH(shares1, user1, user1, 0);

        vm.prank(user2);
        uint256 assets2 = ethVault.redeemETH(shares2, user2, user2, 0);

        assertApproxEqAbs(assets1, deposit1, 2);
        assertApproxEqAbs(assets2, deposit2, 2);
    }

    // ============ Yield Distribution Tests ============

    function testYieldDistribution_ToNGO() public {
        uint256 depositAmount = 50 ether;

        // User deposits
        vm.prank(user1);
        ethVault.depositETH{value: depositAmount}(user1, 0);

        // Set user preferences for yield donation
        vm.prank(user1);
        router.setUserPreference(ngo1, 75); // 75% to NGO

        // Simulate yield by minting aTokens to adapter (represents yield accrual)
        uint256 yieldAmount = 5 ether;
        aWETH.mint(address(aaveAdapter), yieldAmount);

        // Harvest and distribute
        vm.prank(vaultManager);
        ethVault.harvest();

        // Check NGO received yield
        assertGt(weth.balanceOf(ngo1), 0);
        // Calculate expected donation: 75% of yield after 2.5% protocol fee
        uint256 protocolFee = (yieldAmount * 250) / 10_000; // 2.5%
        uint256 netYield = yieldAmount - protocolFee;
        uint256 expectedDonation = (netYield * 75) / 100; // 75% to NGO
        assertEq(router.totalDonated(address(weth)), expectedDonation);
    }

    // ============ Edge Cases and Error Scenarios ============

    function testDepositETH_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert();
        ethVault.depositETH{value: 0}(user1, 0);
    }

    function testDepositETH_InvalidReceiver() public {
        vm.prank(user1);
        vm.expectRevert();
        ethVault.depositETH{value: 1 ether}(address(0), 0);
    }

    function testRedeemETH_InsufficientShares() public {
        vm.prank(user1);
        ethVault.depositETH{value: 1 ether}(user1, 0);

        vm.prank(user1);
        vm.expectRevert();
        ethVault.redeemETH(1000 ether, user1, user1, 0); // More shares than owned
    }

    function testWithdrawETH_ExcessiveAmount() public {
        vm.prank(user1);
        ethVault.depositETH{value: 1 ether}(user1, 0);

        vm.prank(user1);
        vm.expectRevert();
        ethVault.withdrawETH(10 ether, user1, user1, type(uint256).max); // More than deposited
    }

    function testSlippageProtection() public {
        vm.prank(user1);
        uint256 shares = ethVault.depositETH{value: 1 ether}(user1, 0);

        // Try to redeem with high minimum assets requirement
        vm.prank(user1);
        vm.expectRevert();
        ethVault.redeemETH(shares, user1, user1, 2 ether); // Expecting more than possible
    }

    // ============ Strategy Manager Integration ============

    function testStrategyManager_AdapterSwitch() public {
        uint256 depositAmount = 20 ether;

        vm.prank(user1);
        ethVault.depositETH{value: depositAmount}(user1, 0);

        // Deploy second adapter
        vm.prank(admin);
        AaveAdapter secondAdapter = new AaveAdapter(address(weth), address(ethVault), address(aavePool), admin);

        // Switch adapters via strategy manager
        vm.startPrank(admin);
        manager.setAdapterApproval(address(secondAdapter), true);
        manager.setActiveAdapter(address(secondAdapter));
        vm.stopPrank();

        // Verify adapter switch
        assertEq(address(ethVault.activeAdapter()), address(secondAdapter));
    }

    // ============ Gas Optimization Tests ============

    function testGasUsage_DepositETH() public {
        uint256 gasBefore = gasleft();

        vm.prank(user1);
        ethVault.depositETH{value: 1 ether}(user1, 0);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for depositETH:", gasUsed);

        // Should be reasonable gas usage (adjust threshold as needed)
        assertLt(gasUsed, 500_000);
    }

    function testGasUsage_RedeemETH() public {
        vm.prank(user1);
        uint256 shares = ethVault.depositETH{value: 1 ether}(user1, 0);

        uint256 gasBefore = gasleft();

        vm.prank(user1);
        ethVault.redeemETH(shares, user1, user1, 0);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for redeemETH:", gasUsed);

        assertLt(gasUsed, 500_000);
    }

    // ============ Integration with Donation Router ============

    function testDonationRouter_UserSharesUpdate() public {
        uint256 depositAmount = 10 ether;

        vm.prank(user1);
        ethVault.depositETH{value: depositAmount}(user1, 0);

        // Check user shares were updated in donation router
        uint256 userShares = router.userAssetShares(user1, address(weth));
        assertEq(userShares, ethVault.balanceOf(user1));
    }

    // ============ Pause/Emergency Scenarios ============

    function testEmergencyPause() public {
        vm.prank(user1);
        ethVault.depositETH{value: 1 ether}(user1, 0);

        // Emergency pause
        vm.prank(admin);
        ethVault.emergencyPause();

        // Should not be able to deposit/withdraw
        vm.prank(user2);
        vm.expectRevert();
        ethVault.depositETH{value: 1 ether}(user2, 0);
    }
}

// ============ Mock Contracts ============

contract MockWETH is ERC20("Wrapped Ether", "WETH") {
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

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockAToken is ERC20 {
    IERC20 public underlying;

    constructor(string memory name, string memory symbol, uint8 decimals, address _underlying) ERC20(name, symbol) {
        underlying = IERC20(_underlying);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockAavePool {
    IERC20 public asset;
    MockAToken public aToken;

    constructor(address _asset, address _aToken) {
        asset = IERC20(_asset);
        aToken = MockAToken(_aToken);
    }

    function supply(address _asset, uint256 amount, address onBehalfOf, uint16) external {
        require(_asset == address(asset), "asset mismatch");
        asset.transferFrom(msg.sender, address(this), amount);
        aToken.mint(onBehalfOf, amount);
    }

    function withdraw(address _asset, uint256 amount, address to) external returns (uint256) {
        require(_asset == address(asset), "asset mismatch");
        aToken.burn(msg.sender, amount);
        asset.transfer(to, amount);
        return amount;
    }

    function getReserveData(address _asset) external view returns (ReserveData memory) {
        require(_asset == address(asset), "asset mismatch");
        return ReserveData({
            configuration: 0,
            liquidityIndex: 1e27,
            currentLiquidityRate: 0,
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: 0,
            currentStableBorrowRate: 0,
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 0,
            aTokenAddress: address(aToken),
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: address(0),
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
    }
}

struct MockReserveData {
    uint256 configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    uint16 id;
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    address interestRateStrategyAddress;
    uint128 accruedToTreasury;
    uint128 unbacked;
    uint128 isolationModeTotalDebt;
}
