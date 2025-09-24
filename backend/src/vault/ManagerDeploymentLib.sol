// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StrategyManager} from "../manager/StrategyManager.sol";
import {PayoutRouter} from "../payout/PayoutRouter.sol";
import {RoleManager} from "../access/RoleManager.sol";
import {StrategyRegistry} from "../manager/StrategyRegistry.sol";
import {IConfigurableAdapter} from "./IConfigurableAdapter.sol";

/// @notice External contract for deploying StrategyManager instances
/// @dev Deployed separately to reduce factory contract size
contract ManagerDeploymentLib {
    struct DeployManagerParams {
        address vault;
        address roleManager;
        address strategyRegistry;
        address payoutRouter;
        uint64 campaignId;
        uint64 strategyId;
        address adapter;
    }

    /// @notice Deploys and configures a new StrategyManager
    /// @dev This function is external to be used as a library
    function deployManager(DeployManagerParams memory params)
        external
        returns (address manager)
    {
        // Deploy the manager
        manager = address(new StrategyManager(params.vault, params.roleManager));

        // Grant necessary roles
        RoleManager rm = RoleManager(params.roleManager);
        rm.grantRole(rm.ROLE_VAULT_OPS(), manager);

        // Configure the manager
        StrategyManager(manager).setStrategyRegistry(params.strategyRegistry);
        StrategyManager(manager).setPayoutRouter(params.payoutRouter);

        // Register vault with payout router
        PayoutRouter router = PayoutRouter(params.payoutRouter);
        router.registerVault(params.vault, params.campaignId, params.strategyId);
        router.setAuthorizedCaller(params.vault, true);

        // Configure adapter if present
        if (params.adapter != address(0)) {
            // Try to configure adapter for vault if it supports the interface
            try IConfigurableAdapter(params.adapter).configureForVault(params.vault) {} catch {}

            StrategyManager(manager).setAdapterApproval(params.adapter, true);
            StrategyManager(manager).setActiveAdapter(params.adapter);
        }

        return manager;
    }
}