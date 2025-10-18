// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RoleAware} from "../access/RoleAware.sol";
import {Errors} from "../utils/Errors.sol";
import {RegistryTypes} from "../manager/RegistryTypes.sol";
import {StrategyRegistry} from "../manager/StrategyRegistry.sol";
import {CampaignRegistry} from "../campaign/CampaignRegistry.sol";
import {PayoutRouter} from "../payout/PayoutRouter.sol";
import {VaultDeploymentLib} from "./VaultDeploymentLib.sol";
import {ManagerDeploymentLib} from "./ManagerDeploymentLib.sol";

/// @title CampaignVaultFactory
/// @notice Deploys campaign-bound ERC-4626 vaults and associated strategy managers using external helper contracts.
/// @dev Uses external helper contracts to minimize factory bytecode size
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

    /// @notice Helper contracts for deployment
    VaultDeploymentLib public immutable vaultDeployer;
    ManagerDeploymentLib public immutable managerDeployer;

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

    constructor(
        address roleManager_,
        address strategyRegistry_,
        address campaignRegistry_,
        address payoutRouter_,
        address vaultDeployer_,
        address managerDeployer_
    ) RoleAware(roleManager_) {
        if (
            strategyRegistry_ == address(0) || campaignRegistry_ == address(0) || payoutRouter_ == address(0)
                || vaultDeployer_ == address(0) || managerDeployer_ == address(0)
        ) {
            revert Errors.ZeroAddress();
        }

        strategyRegistry = StrategyRegistry(strategyRegistry_);
        campaignRegistry = CampaignRegistry(campaignRegistry_);
        payoutRouter = PayoutRouter(payoutRouter_);
        vaultDeployer = VaultDeploymentLib(vaultDeployer_);
        managerDeployer = ManagerDeploymentLib(managerDeployer_);

        CAMPAIGN_ADMIN_ROLE = roleManager.ROLE_CAMPAIGN_ADMIN();
        STRATEGY_ADMIN_ROLE = roleManager.ROLE_STRATEGY_ADMIN();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
    }

    /*//////////////////////////////////////////////////////////////
                                DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploy a new campaign vault for a specific strategy attachment.
    /// @dev Caller must be campaign curator, campaign admin, or strategy admin.
    /// @dev Uses external libraries to minimize contract size
    function deployCampaignVault(
        uint64 campaignId,
        uint64 strategyId,
        RegistryTypes.LockProfile lockProfile,
        string calldata name,
        string calldata symbol,
        uint256 minDepositAmount
    ) external returns (Deployment memory deployment) {
        // Validate authorization
        CampaignRegistry.Campaign memory campaign = campaignRegistry.getCampaign(campaignId);
        if (!_isCuratorOrPrivileged(campaign.curator, msg.sender)) revert Errors.UnauthorizedCurator();

        // Get strategy for adapter info
        StrategyRegistry.Strategy memory strategy = strategyRegistry.getStrategy(strategyId);

        // Deploy vault using external library
        VaultDeploymentLib.DeployVaultParams memory vaultParams = VaultDeploymentLib.DeployVaultParams({
            strategyRegistry: address(strategyRegistry),
            campaignRegistry: address(campaignRegistry),
            campaignId: campaignId,
            strategyId: strategyId,
            lockProfile: lockProfile,
            name: name,
            symbol: symbol,
            minDepositAmount: minDepositAmount,
            roleManager: address(roleManager)
        });

        address vault = vaultDeployer.deployVault(vaultParams);

        // Deploy manager using external library
        ManagerDeploymentLib.DeployManagerParams memory managerParams = ManagerDeploymentLib.DeployManagerParams({
            vault: vault,
            roleManager: address(roleManager),
            strategyRegistry: address(strategyRegistry),
            payoutRouter: address(payoutRouter),
            campaignId: campaignId,
            strategyId: strategyId,
            adapter: strategy.adapter
        });

        address manager = managerDeployer.deployManager(managerParams);

        // Record deployment
        uint256 deploymentId = _deployments.length;
        deployment = Deployment({
            vault: vault,
            strategyManager: manager,
            campaignId: campaignId,
            strategyId: strategyId,
            lockProfile: lockProfile,
            deployedAt: block.timestamp
        });

        _deployments.push(deployment);
        _deploymentIndexByVault[vault] = deploymentId + 1;

        emit CampaignVaultDeployed(
            deploymentId, campaignId, strategyId, vault, manager, lockProfile, name, symbol
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