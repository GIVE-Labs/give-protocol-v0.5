// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Fork test against Sepolia Aave V3 to sanity-check integration.
/// Requires env:
/// - FORK_RPC_URL
/// - FORK_USDC (ERC20 on Sepolia)
/// - FORK_AAVE_POOL (Aave V3 Pool on Sepolia)
contract Fork_AaveSepoliaTest is Test {
    function testFork_Aave_Supply_Withdraw() external {
        string memory url = vm.envOr("FORK_RPC_URL", string(""));
        address usdc = vm.envOr("FORK_USDC", address(0));
        address pool = vm.envOr("FORK_AAVE_POOL", address(0));

        // Skip if not configured
        if (bytes(url).length == 0 || usdc == address(0) || pool == address(0)) {
            return;
        }

        uint256 fork = vm.createFork(url);
        vm.selectFork(fork);

        // Deploy adapter with this test contract as the vault
        AaveAdapter adapter = new AaveAdapter(usdc, address(this), pool, address(this));

        // Fund adapter with USDC using deal (ERC20 cheatcode)
        uint256 amount = 10_000e6;
        deal(usdc, address(adapter), amount, true);

        // Invest into Aave
        vm.prank(address(this));
        adapter.invest(amount);

        // Verify aToken minted via adapter view
        (,,,, uint256 aTokenBalance) = adapter.getAdapterStats();
        assertGt(aTokenBalance, 0, "aToken balance should be > 0 after supply");

        // Divest and ensure funds return
        vm.prank(address(this));
        uint256 returned = adapter.divest(amount);
        assertGt(returned, 0, "should withdraw");
    }
}
