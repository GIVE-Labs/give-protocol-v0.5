// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RoleAware} from "../access/RoleAware.sol";
import {RoleManager} from "../access/RoleManager.sol";
import {Errors} from "../utils/Errors.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {StrategyRegistry} from "../manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../campaign/CampaignRegistry.sol";
import {StrategyManager} from "../manager/StrategyManager.sol";
import {CampaignVault} from "./CampaignVault.sol";
import {PayoutRouter} from "../payout/PayoutRouter.sol";

interface IConfigurableAdapter {
    function configureForVault(address vault) external;
}

/// @title CampaignVaultFactory
/// @notice Deploys campaign-bound ERC-4626 vaults and associated strategy managers.
contract CampaignVaultFactory is RoleAware {
    struct Deployment {
        address vault;
        address strategyManager;
        uint64 campaignId;
        uint64 strategyId;
        RegistryTypes.LockProfile lockProfile;
        uint256 deployedAt;
    }

    /// @notice References to core registries.
    StrategyRegistry public immutable strategyRegistry;
    CampaignRegistry public immutable campaignRegistry;
    PayoutRouter public immutable payoutRouter;

    /// @dev Storage of all deployments.
    Deployment[] private _deployments;
    mapping(address => uint256) private _deploymentIndexByVault; // 1-based index

    /// @notice Cached role ids.
    bytes32 public immutable CAMPAIGN_ADMIN_ROLE;
    bytes32 public immutable STRATEGY_ADMIN_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;

    /// @notice Emitted when a new campaign vault is deployed.
    event CampaignVaultDeployed(
        uint256 indexed deploymentId,
        uint64 indexed campaignId,
        uint64 indexed strategyId,
        address vault,
        address strategyManager,
        RegistryTypes.LockProfile lockProfile,
        string name,
        string symbol
    );

    constructor(address roleManager_, address strategyRegistry_, address campaignRegistry_, address payoutRouter_)
        RoleAware(roleManager_)
    {
        if (strategyRegistry_ == address(0) || campaignRegistry_ == address(0) || payoutRouter_ == address(0)) {
            revert Errors.ZeroAddress();
        }

        strategyRegistry = StrategyRegistry(strategyRegistry_);
        campaignRegistry = CampaignRegistry(campaignRegistry_);
        payoutRouter = PayoutRouter(payoutRouter_);

        CAMPAIGN_ADMIN_ROLE = roleManager.ROLE_CAMPAIGN_ADMIN();
        STRATEGY_ADMIN_ROLE = roleManager.ROLE_STRATEGY_ADMIN();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
    }

    /*//////////////////////////////////////////////////////////////
                                DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy a new campaign vault for a specific strategy attachment.
    /// @dev Caller must be campaign curator, campaign admin, or strategy admin.
    function deployCampaignVault(
        uint64 campaignId,
        uint64 strategyId,
        RegistryTypes.LockProfile lockProfile,
        string calldata name,
        string calldata symbol
    ) external returns (Deployment memory deployment) {
        CampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(campaignId);
        if (!_isCuratorOrPrivileged(campaign.curator, msg.sender)) revert Errors.UnauthorizedCurator();
        if (campaign.status != RegistryTypes.CampaignStatus.Active) revert Errors.CampaignNotActive();
        if (!campaignRegistry.isStrategyAttached(campaignId, strategyId)) revert Errors.StrategyNotFound();

        StrategyRegistry.Strategy memory strategy = strategyRegistry.getStrategy(strategyId);
        if (strategy.status != RegistryTypes.StrategyStatus.Active) revert Errors.StrategyInactive();
        if (strategy.asset == address(0)) revert Errors.ZeroAddress();

        IERC20 asset = IERC20(strategy.asset);

        CampaignVault vault = new CampaignVault(
            asset,
            name,
            symbol,
            address(roleManager),
            campaignId,
            strategyId,
            lockProfile
        );

        StrategyManager manager = new StrategyManager(address(vault), address(roleManager));

        // Assign shared roles so the manager can control the vault.
        RoleManager(address(roleManager)).grantRole(roleManager.ROLE_VAULT_OPS(), address(manager));

        // Wire registry and router context.
        manager.setStrategyRegistry(address(strategyRegistry));
        manager.setDonationRouter(address(payoutRouter));
        payoutRouter.registerVault(address(vault), campaignId, strategyId);
        payoutRouter.setAuthorizedCaller(address(vault), true);

        // Attempt to configure adapter for the newly deployed vault if supported.
        try IConfigurableAdapter(strategy.adapter).configureForVault(address(vault)) {} catch {}

        manager.setAdapterApproval(strategy.adapter, true);
        manager.setActiveAdapter(strategy.adapter);

        uint256 deploymentId = _deployments.length;
        deployment = Deployment({
            vault: address(vault),
            strategyManager: address(manager),
            campaignId: campaignId,
            strategyId: strategyId,
            lockProfile: lockProfile,
            deployedAt: block.timestamp
        });

        _deployments.push(deployment);
        _deploymentIndexByVault[address(vault)] = deploymentId + 1;

        emit CampaignVaultDeployed(
            deploymentId,
            campaignId,
            strategyId,
            address(vault),
            address(manager),
            lockProfile,
            name,
            symbol
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW HELPERS
    //////////////////////////////////////////////////////////////*/

    function deploymentsLength() external view returns (uint256) {
        return _deployments.length;
    }

    function getDeployment(uint256 deploymentId) external view returns (Deployment memory) {
        require(deploymentId < _deployments.length, "deployment OOB");
        return _deployments[deploymentId];
    }

    function deploymentOf(address vault) external view returns (Deployment memory) {
        uint256 index = _deploymentIndexByVault[vault];
        require(index != 0, "vault not found");
        return _deployments[index - 1];
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _isCuratorOrPrivileged(address curator, address account) private view returns (bool) {
        if (account == curator) return true;
        if (roleManager.hasRole(CAMPAIGN_ADMIN_ROLE, account)) return true;
        if (roleManager.hasRole(STRATEGY_ADMIN_ROLE, account)) return true;
        if (roleManager.hasRole(GUARDIAN_ROLE, account)) return true;
        return false;
    }
}
