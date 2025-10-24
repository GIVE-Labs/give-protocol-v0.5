// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";

// WETH interface
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

// Minimal IPool interface for testing
interface IPool {
    function getReserveData(
        address asset
    )
        external
        view
        returns (
            uint256,
            uint128,
            uint128,
            uint128,
            uint128,
            uint128,
            uint40,
            address,
            address,
            address,
            address,
            uint8
        );
}

/**
 * @title Fork_AaveBaseSepoliaTest
 * @notice Fork test to verify AaveAdapter integration with real Aave V3 on Base Sepolia
 * @dev Run with: forge test --match-contract Fork_AaveBaseSepoliaTest --fork-url $BASE_SEPOLIA_RPC -vv
 */
contract Fork_AaveBaseSepoliaTest is Test {
    // Base Sepolia addresses (verified from bgd-labs/aave-address-book)
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant AAVE_POOL = 0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27;

    AaveAdapter adapter;
    address aWETH; // Will be fetched from adapter after deployment
    address vault;
    address admin;
    address donor;

    function setUp() public {
        // Check if fork URL is provided, skip if not
        string memory forkUrl = vm.envOr("BASE_SEPOLIA_RPC_URL", string(""));
        if (bytes(forkUrl).length == 0) {
            // Skip test if no fork URL configured
            vm.skip(true);
            return;
        }

        // Create and select fork
        uint256 forkId = vm.createFork(forkUrl);
        vm.selectFork(forkId);

        // Verify we're on Base Sepolia
        require(block.chainid == 84532, "Must fork Base Sepolia (chain 84532)");

        vault = makeAddr("vault");
        admin = makeAddr("admin");
        donor = makeAddr("donor");

        // Deploy AaveAdapter
        adapter = new AaveAdapter(WETH, vault, AAVE_POOL, admin);

        // Get the actual aWETH address from the adapter
        aWETH = address(adapter.aToken());

        console.log("=== Fork Test Setup ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("WETH:", WETH);
        console.log("Aave Pool:", AAVE_POOL);
        console.log("aWETH:", aWETH);
        console.log("Adapter:", address(adapter));
    }

    function test_AaveIntegration_DepositWithdrawCycle() public {
        uint256 depositAmount = 1 ether;

        // Fund vault with ETH and wrap to WETH
        vm.deal(vault, depositAmount);
        vm.prank(vault);
        IWETH(WETH).deposit{value: depositAmount}();

        // 1. Transfer WETH to adapter, then invest
        vm.startPrank(vault);
        IERC20(WETH).transfer(address(adapter), depositAmount);
        adapter.invest(depositAmount);
        vm.stopPrank();

        // 2. Verify WETH was supplied to Aave (aWETH balance should increase)
        uint256 aTokenBalance = IERC20(aWETH).balanceOf(address(adapter));
        assertGt(aTokenBalance, 0, "Adapter should hold aWETH");
        assertApproxEqRel(
            aTokenBalance,
            depositAmount,
            0.01e18, // 1% tolerance
            "aWETH balance should match deposit"
        );

        console.log("\n=== After Deposit ===");
        console.log("Adapter aWETH balance:", aTokenBalance);
        console.log("Adapter total assets:", adapter.totalAssets());

        // 3. Verify totalAssets reports correct amount
        uint256 totalAssets = adapter.totalAssets();
        assertApproxEqRel(
            totalAssets,
            depositAmount,
            0.01e18,
            "Total assets should match deposit"
        );

        // 4. Simulate time passing to accrue yield (1 day)
        skip(1 days);

        // 5. Verify yield accrual (totalAssets should increase slightly)
        uint256 totalAssetsAfterYield = adapter.totalAssets();
        assertGe(
            totalAssetsAfterYield,
            totalAssets,
            "Total assets should increase or stay same after time"
        );

        console.log("\n=== After 1 Day ===");
        console.log("Total assets:", totalAssetsAfterYield);
        console.log(
            "Yield accrued:",
            totalAssetsAfterYield > totalAssets
                ? totalAssetsAfterYield - totalAssets
                : 0
        );

        // 6. Harvest yield (if any)
        vm.prank(vault);
        (uint256 profit, uint256 loss) = adapter.harvest();
        console.log("\n=== Harvest ===");
        console.log("Harvested profit:", profit);
        console.log("Harvested loss:", loss);

        // 7. Divest all assets
        uint256 assetsBeforeDivest = adapter.totalAssets();
        vm.prank(vault);
        uint256 divested = adapter.divest(assetsBeforeDivest);

        assertGt(divested, 0, "Should divest some WETH");
        assertApproxEqRel(
            divested,
            assetsBeforeDivest,
            0.01e18,
            "Divested should match total assets"
        );

        console.log("\n=== After Divestment ===");
        console.log("Divested WETH:", divested);
        console.log("Vault WETH balance:", IERC20(WETH).balanceOf(vault));
        console.log("Adapter remaining assets:", adapter.totalAssets());

        // 8. Verify adapter is empty after divestment
        assertLt(
            adapter.totalAssets(),
            0.001 ether, // Allow dust
            "Adapter should be nearly empty"
        );
    }

    function test_AaveIntegration_VerifyAavePoolLiquidity() public view {
        // Verify the aWETH token exists
        assertGt(aWETH.code.length, 0, "aWETH should be a contract");

        console.log("\n=== Aave Pool Liquidity ===");
        console.log("aWETH token:", aWETH);
        console.log("Verified: aWETH is deployed");
    }

    function test_AaveIntegration_MultipleDepositWithdraw() public {
        uint256 firstDeposit = 0.5 ether;
        uint256 secondDeposit = 0.3 ether;

        // Fund vault with ETH and wrap to WETH
        vm.deal(vault, firstDeposit + secondDeposit);
        vm.prank(vault);
        IWETH(WETH).deposit{value: firstDeposit + secondDeposit}();

        vm.startPrank(vault);

        // First deposit
        IERC20(WETH).transfer(address(adapter), firstDeposit);
        adapter.invest(firstDeposit);
        uint256 assetsAfterFirst = adapter.totalAssets();
        assertApproxEqRel(
            assetsAfterFirst,
            firstDeposit,
            0.01e18,
            "First deposit should be recorded"
        );

        // Second deposit
        IERC20(WETH).transfer(address(adapter), secondDeposit);
        adapter.invest(secondDeposit);
        uint256 assetsAfterSecond = adapter.totalAssets();
        assertApproxEqRel(
            assetsAfterSecond,
            firstDeposit + secondDeposit,
            0.01e18,
            "Second deposit should be added"
        );

        console.log("\n=== Multiple Deposits ===");
        console.log("After first deposit:", assetsAfterFirst);
        console.log("After second deposit:", assetsAfterSecond);

        // Partial divestment
        uint256 partialDivest = 0.4 ether;
        uint256 divested = adapter.divest(partialDivest);
        assertApproxEqRel(
            divested,
            partialDivest,
            0.01e18,
            "Partial divest should match requested"
        );

        uint256 remaining = adapter.totalAssets();
        assertApproxEqRel(
            remaining,
            assetsAfterSecond - divested,
            0.01e18,
            "Remaining assets should be correct"
        );

        console.log("After partial divest:", remaining);

        vm.stopPrank();
    }

    function test_AaveIntegration_ZeroDeposit() public {
        vm.prank(vault);
        vm.expectRevert(); // Should revert on zero deposit
        adapter.invest(0);
    }

    function test_AaveIntegration_UnauthorizedAccess() public {
        uint256 amount = 1 ether;

        // Fund vault with ETH and wrap to WETH
        vm.deal(vault, amount);
        vm.prank(vault);
        IWETH(WETH).deposit{value: amount}();

        vm.prank(vault);
        IERC20(WETH).transfer(address(adapter), amount);
        vm.prank(vault);
        adapter.invest(amount);

        // Try to divest from non-vault address
        vm.prank(donor);
        vm.expectRevert(); // Should revert - only vault can divest
        adapter.divest(amount);
    }
}
