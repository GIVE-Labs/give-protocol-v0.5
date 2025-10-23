// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IACLManager.sol";
import "../registry/CampaignRegistry.sol";
import "../registry/StrategyRegistry.sol";
import "../vault/CampaignVault4626.sol";
import "../types/GiveTypes.sol";
import "../payout/PayoutRouter.sol";

/// @title CampaignVaultFactory
/// @notice Deploys campaign-specific vaults and wires them into strategy/campaign registries.
contract CampaignVaultFactory is Initializable, UUPSUpgradeable {
    IACLManager public aclManager;
    CampaignRegistry public campaignRegistry;
    StrategyRegistry public strategyRegistry;
    PayoutRouter public payoutRouter;

    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    struct DeployParams {
        bytes32 campaignId;
        bytes32 strategyId;
        bytes32 lockProfile;
        address asset;
        address admin;
        string name;
        string symbol;
    }

    error ZeroAddress();
    error Unauthorized(bytes32 roleId, address account);
    error DeploymentExists(bytes32 key);
    error CampaignStrategyMismatch(bytes32 campaignId, bytes32 expectedStrategy, bytes32 providedStrategy);
    error InvalidParameters();

    mapping(bytes32 => address) private _deployments;

    event VaultCreated(
        bytes32 indexed campaignId,
        bytes32 indexed strategyId,
        bytes32 lockProfile,
        address indexed vault,
        bytes32 vaultId
    );

    modifier onlyRole(bytes32 roleId) {
        if (!aclManager.hasRole(roleId, msg.sender)) {
            revert Unauthorized(roleId, msg.sender);
        }
        _;
    }

    function initialize(address acl, address campaignRegistry_, address strategyRegistry_, address payoutRouter_)
        external
        initializer
    {
        if (
            acl == address(0) || campaignRegistry_ == address(0) || strategyRegistry_ == address(0)
                || payoutRouter_ == address(0)
        ) {
            revert ZeroAddress();
        }

        aclManager = IACLManager(acl);
        campaignRegistry = CampaignRegistry(campaignRegistry_);
        strategyRegistry = StrategyRegistry(strategyRegistry_);
        payoutRouter = PayoutRouter(payoutRouter_);
    }

    function deployCampaignVault(DeployParams calldata params)
        external
        onlyRole(aclManager.campaignAdminRole())
        returns (address vault)
    {
        if (params.asset == address(0) || params.admin == address(0) || bytes(params.name).length == 0) {
            revert InvalidParameters();
        }

        bytes32 key = _deploymentKey(params.campaignId, params.strategyId, params.lockProfile);
        if (_deployments[key] != address(0)) revert DeploymentExists(key);

        GiveTypes.CampaignConfig memory campaignCfg = campaignRegistry.getCampaign(params.campaignId);
        if (campaignCfg.strategyId != params.strategyId) {
            revert CampaignStrategyMismatch(params.campaignId, campaignCfg.strategyId, params.strategyId);
        }

        CampaignVault4626 newVault =
            new CampaignVault4626(IERC20(params.asset), params.name, params.symbol, params.admin);
        vault = address(newVault);

        newVault.initializeCampaign(params.campaignId, params.strategyId, params.lockProfile, address(this));

        campaignRegistry.setCampaignVault(params.campaignId, vault, params.lockProfile);
        strategyRegistry.registerStrategyVault(params.strategyId, vault);

        payoutRouter.registerCampaignVault(vault, params.campaignId);
        payoutRouter.setAuthorizedCaller(vault, true);

        _deployments[key] = vault;
        bytes32 vaultId = newVault.vaultId();

        emit VaultCreated(params.campaignId, params.strategyId, params.lockProfile, vault, vaultId);
    }

    function getDeployment(bytes32 campaignId, bytes32 strategyId, bytes32 lockProfile)
        external
        view
        returns (address)
    {
        return _deployments[_deploymentKey(campaignId, strategyId, lockProfile)];
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Unauthorized(ROLE_UPGRADER, msg.sender);
        }
    }

    function _deploymentKey(bytes32 campaignId, bytes32 strategyId, bytes32 lockProfile)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(campaignId, strategyId, lockProfile));
    }
}
