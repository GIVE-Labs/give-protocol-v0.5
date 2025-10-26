// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IACLManager.sol";
import "../registry/CampaignRegistry.sol";
import "../registry/StrategyRegistry.sol";
import "../vault/CampaignVault4626.sol";
import "../types/GiveTypes.sol";
import "../payout/PayoutRouter.sol";

/// @title CampaignVaultFactory
/// @notice Deploys campaign vaults via EIP-1167 minimal proxies for gas efficiency
/// @dev Uses deterministic CREATE2 salts for predictable addresses
contract CampaignVaultFactory is Initializable, UUPSUpgradeable {
    using Clones for address;

    IACLManager public aclManager;
    CampaignRegistry public campaignRegistry;
    StrategyRegistry public strategyRegistry;
    PayoutRouter public payoutRouter;
    address public vaultImplementation;

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

    event VaultCreated(
        bytes32 indexed campaignId,
        bytes32 indexed strategyId,
        bytes32 lockProfile,
        address indexed vault,
        bytes32 vaultId
    );
    event ImplementationUpdated(address indexed oldImpl, address indexed newImpl);

    modifier onlyRole(bytes32 roleId) {
        if (!aclManager.hasRole(roleId, msg.sender)) {
            revert Unauthorized(roleId, msg.sender);
        }
        _;
    }

    function initialize(
        address acl,
        address campaignRegistry_,
        address strategyRegistry_,
        address payoutRouter_,
        address vaultImplementation_
    ) external initializer {
        if (
            acl == address(0) || campaignRegistry_ == address(0) || strategyRegistry_ == address(0)
                || payoutRouter_ == address(0) || vaultImplementation_ == address(0)
        ) {
            revert ZeroAddress();
        }

        aclManager = IACLManager(acl);
        campaignRegistry = CampaignRegistry(campaignRegistry_);
        strategyRegistry = StrategyRegistry(strategyRegistry_);
        payoutRouter = PayoutRouter(payoutRouter_);
        vaultImplementation = vaultImplementation_;
    }

    /// @notice Update vault implementation for future deployments
    /// @dev Only affects new deployments, existing vaults unchanged
    function setVaultImplementation(address newImpl) external onlyRole(aclManager.campaignAdminRole()) {
        if (newImpl == address(0)) revert ZeroAddress();
        address oldImpl = vaultImplementation;
        vaultImplementation = newImpl;
        emit ImplementationUpdated(oldImpl, newImpl);
    }

    function deployCampaignVault(DeployParams calldata params)
        external
        onlyRole(aclManager.campaignAdminRole())
        returns (address)
    {
        if (params.asset == address(0) || params.admin == address(0) || bytes(params.name).length == 0) {
            revert InvalidParameters();
        }

        GiveTypes.CampaignConfig memory campaignCfg = campaignRegistry.getCampaign(params.campaignId);
        if (campaignCfg.strategyId != params.strategyId) {
            revert CampaignStrategyMismatch(params.campaignId, campaignCfg.strategyId, params.strategyId);
        }

        // Compute deterministic salt from campaign params
        bytes32 salt = keccak256(abi.encodePacked(params.campaignId, params.strategyId, params.lockProfile));

        // Predict address and check if already deployed
        address predicted = Clones.predictDeterministicAddress(vaultImplementation, salt, address(this));
        if (predicted.code.length > 0) {
            revert DeploymentExists(salt);
        }

        // Deploy EIP-1167 minimal proxy clone
        address vault = Clones.cloneDeterministic(vaultImplementation, salt);
        CampaignVault4626 vaultContract = CampaignVault4626(payable(vault));

        // Initialize the clone (grants admin role to params.admin)
        vaultContract.initializeCampaign(params.campaignId, params.strategyId, params.lockProfile, params.admin);

        // Wire into registries and router
        campaignRegistry.setCampaignVault(params.campaignId, vault, params.lockProfile);
        strategyRegistry.registerStrategyVault(params.strategyId, vault);
        payoutRouter.registerCampaignVault(vault, params.campaignId);
        payoutRouter.setAuthorizedCaller(vault, true);

        bytes32 vaultId = vaultContract.vaultId();
        emit VaultCreated(params.campaignId, params.strategyId, params.lockProfile, vault, vaultId);

        return vault;
    }

    /// @notice Predict vault address before deployment
    /// @dev Useful for off-chain address computation
    function predictVaultAddress(bytes32 campaignId, bytes32 strategyId, bytes32 lockProfile)
        external
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(campaignId, strategyId, lockProfile));
        return Clones.predictDeterministicAddress(vaultImplementation, salt, address(this));
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Unauthorized(ROLE_UPGRADER, msg.sender);
        }
    }
}
