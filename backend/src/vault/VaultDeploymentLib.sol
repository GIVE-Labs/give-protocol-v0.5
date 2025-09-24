// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CampaignVault} from "./CampaignVault.sol";
import {CampaignRegistry} from "../campaign/CampaignRegistry.sol";
import {StrategyRegistry} from "../manager/StrategyRegistry.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {Errors} from "../utils/Errors.sol";

/// @notice External contract for deploying CampaignVault instances
/// @dev Deployed separately to reduce factory contract size
contract VaultDeploymentLib {
    struct DeployVaultParams {
        address strategyRegistry;
        address campaignRegistry;
        uint64 campaignId;
        uint64 strategyId;
        RegistryTypes.LockProfile lockProfile;
        string name;
        string symbol;
        uint256 minDepositAmount;
        address roleManager;
    }

    /// @notice Deploys a new CampaignVault
    /// @dev This function is external to be used as a library
    function deployVault(DeployVaultParams memory params)
        external
        returns (address vault)
    {
        // Validate campaign
        CampaignRegistry registry = CampaignRegistry(params.campaignRegistry);
        (address curator, RegistryTypes.CampaignStatus status) = registry.getCampaignCore(params.campaignId);

        if (status != RegistryTypes.CampaignStatus.Active) {
            revert Errors.CampaignNotActive();
        }

        // Validate strategy
        StrategyRegistry strategyReg = StrategyRegistry(params.strategyRegistry);
        (address asset, address adapter, RegistryTypes.StrategyStatus strategyStatus) =
            strategyReg.getStrategyCore(params.strategyId);

        if (strategyStatus != RegistryTypes.StrategyStatus.Active) {
            revert Errors.StrategyInactive();
        }

        if (asset == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Check strategy is attached to campaign
        if (!registry.isStrategyAttached(params.campaignId, params.strategyId)) {
            revert Errors.StrategyNotFound();
        }

        // Deploy the vault
        vault = address(new CampaignVault(
            IERC20(asset),
            params.name,
            params.symbol,
            params.roleManager,
            params.campaignId,
            params.strategyId,
            params.lockProfile,
            params.minDepositAmount
        ));

        return vault;
    }
}