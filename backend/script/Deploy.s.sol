// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {GiveVault4626} from "../src/vault/GiveVault4626.sol";
import {StrategyManager} from "../src/manager/StrategyManager.sol";
import {AaveAdapter} from "../src/adapters/AaveAdapter.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";
import {DonationRouter} from "../src/donation/DonationRouter.sol";

contract Deploy is Script {
    struct Deployed {
        address vault;
        address manager;
        address adapter;
        address registry;
        address router;
    }

    function run() external returns (Deployed memory out) {
        // Required env
        string memory account = vm.envString("ACCOUNT");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        // Asset configuration: allow overriding the asset via ASSET_ADDRESS for multi-asset deployments
        // Fallback to USDC_ADDRESS for backward compatibility
        address usdc = vm.envAddress("USDC_ADDRESS");
        address assetAddress = vm.envOr("ASSET_ADDRESS", usdc);

        // Optional naming overrides for the vault
        string memory assetName = vm.envOr("ASSET_NAME", string("GIVE Vault USDC"));
        string memory assetSymbol = vm.envOr("ASSET_SYMBOL", string("gvUSDC"));
        address aavePool = vm.envAddress("AAVE_POOL_ADDRESS");
        address feeRecipient = vm.envOr("FEE_RECIPIENT_ADDRESS", admin);

        uint256 cashBufferBps = vm.envOr("CASH_BUFFER_BPS", uint256(100)); // 1%
        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(50)); // 0.5%
        uint256 maxLossBps = vm.envOr("MAX_LOSS_BPS", uint256(50)); // 0.5%
        uint256 feeBps = vm.envOr("FEE_BPS", uint256(250)); // 2.5%

        vm.startBroadcast();

        NGORegistry registry = new NGORegistry(admin);
        DonationRouter router = new DonationRouter(admin, address(registry), feeRecipient, feeBps);

        GiveVault4626 vault = new GiveVault4626(IERC20(assetAddress), assetName, assetSymbol, admin);
        StrategyManager manager = new StrategyManager(address(vault), admin);
        AaveAdapter adapter = new AaveAdapter(assetAddress, address(vault), aavePool, admin);

        // Wire roles & params
        registry.grantRole(registry.DONATION_RECORDER_ROLE(), address(router));
        router.setAuthorizedCaller(address(vault), true);

        // Allow the StrategyManager to configure the vault
        vault.grantRole(vault.VAULT_MANAGER_ROLE(), address(manager));

        manager.setAdapterApproval(address(adapter), true);
        manager.setActiveAdapter(address(adapter));
        manager.updateVaultParameters(cashBufferBps, slippageBps, maxLossBps);
        manager.setDonationRouter(address(router));

        vm.stopBroadcast();

        console.log("Vault:", address(vault));
        console.log("StrategyManager:", address(manager));
        console.log("AaveAdapter:", address(adapter));
        console.log("NGORegistry:", address(registry));
        console.log("DonationRouter:", address(router));

        return Deployed({
            vault: address(vault),
            manager: address(manager),
            adapter: address(adapter),
            registry: address(registry),
            router: address(router)
        });
    }
}
