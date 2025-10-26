// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./GiveVault4626.sol";
import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

/// @title CampaignVault4626
/// @notice Campaign-aware extension of the GIVE vault with shared storage metadata.
contract CampaignVault4626 is GiveVault4626 {
    bool private _campaignInitialized;

    event CampaignMetadataInitialized(
        bytes32 indexed campaignId, bytes32 indexed strategyId, bytes32 lockProfile, address indexed factory
    );

    error CampaignAlreadyInitialized();
    error UnauthorizedInitializer(address caller);

    constructor(IERC20 asset, string memory name, string memory symbol, address admin)
        GiveVault4626(asset, name, symbol, admin)
    {}

    /// @notice One-time initializer invoked by the factory to bind campaign metadata.
    /// @param campaignId The campaign this vault is associated with
    /// @param strategyId The yield strategy this vault uses
    /// @param lockProfile The lock profile (flexible/locked/progressive)
    /// @param admin The admin address to grant DEFAULT_ADMIN_ROLE (for ACL setup)
    function initializeCampaign(bytes32 campaignId, bytes32 strategyId, bytes32 lockProfile, address admin) external {
        if (_campaignInitialized) revert CampaignAlreadyInitialized();
        if (admin == address(0)) revert UnauthorizedInitializer(msg.sender);

        // Grant DEFAULT_ADMIN_ROLE to the admin for post-initialization setup
        // This allows the admin to call setACLManager and configure the vault
        if (!hasRole(DEFAULT_ADMIN_ROLE, admin)) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }

        bytes32 id = vaultId();
        GiveTypes.CampaignVaultMeta storage meta = StorageLib.campaignVaultMeta(id);
        meta.id = id;
        meta.campaignId = campaignId;
        meta.strategyId = strategyId;
        meta.lockProfile = lockProfile;
        meta.factory = msg.sender; // Factory is the caller
        meta.exists = true;

        _campaignInitialized = true;

        emit CampaignMetadataInitialized(campaignId, strategyId, lockProfile, msg.sender);
    }

    /// @notice Returns the campaign metadata bound to this vault.
    function getCampaignMetadata()
        external
        view
        returns (bytes32 campaignId, bytes32 strategyId, bytes32 lockProfile, address factory)
    {
        GiveTypes.CampaignVaultMeta storage meta = StorageLib.ensureCampaignVault(vaultId());
        return (meta.campaignId, meta.strategyId, meta.lockProfile, meta.factory);
    }

    function campaignInitialized() external view returns (bool) {
        return _campaignInitialized;
    }
}
