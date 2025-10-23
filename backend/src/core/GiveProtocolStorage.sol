// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DataTypes} from "../libraries/types/DataTypes.sol";

/**
 * @title GiveProtocolStorage
 * @author GIVE Protocol
 * @notice Diamond Storage implementation for GIVE Protocol
 * @dev EIP-2535 compliant storage pattern to prevent storage collisions on upgrades
 *      All protocol state is stored in a single AppStorage struct at a deterministic slot
 *      Following YOLO Protocol V1 architecture pattern
 */
abstract contract GiveProtocolStorage {
    // ============================================================
    // STORAGE SLOT
    // ============================================================

    /// @notice Diamond storage slot - keccak256("give.protocol.storage.v1") - 1
    bytes32 internal constant GIVE_STORAGE_POSITION =
        bytes32(uint256(keccak256("give.protocol.storage.v1")) - 1);

    // ============================================================
    // APP STORAGE STRUCT
    // ============================================================

    /**
     * @notice Main protocol storage struct
     * @dev All protocol state in one struct to avoid storage collisions
     *      Adding new fields should always append to the end
     *      Never change the order of existing fields
     */
    struct AppStorage {
        // ============ Core Addresses (immutable references) ============
        address aclManager;              // Access control manager
        address protocolTreasury;        // Protocol fee recipient
        address payoutRouter;            // Payout distribution router
        address strategyRegistry;        // Strategy registry
        address campaignRegistry;        // Campaign registry
        
        // ============ Vault Registry ============
        /// @dev vault address => vault configuration
        mapping(address => DataTypes.VaultConfig) vaults;
        /// @dev array of all vault addresses
        address[] vaultList;
        /// @dev quick lookup for vault existence
        mapping(address => bool) isVault;
        
        // ============ Adapter Registry ============
        /// @dev adapter address => adapter configuration
        mapping(address => DataTypes.AdapterConfig) adapters;
        /// @dev array of all adapter addresses
        address[] adapterList;
        /// @dev quick lookup for adapter existence
        mapping(address => bool) isAdapter;
        /// @dev vault => array of adapter addresses
        mapping(address => address[]) vaultAdapters;
        /// @dev vault => adapter => array index for O(1) removal
        mapping(address => mapping(address => uint256)) vaultAdapterIndex;
        
        // ============ Campaign Registry ============
        /// @dev campaignId => campaign configuration
        mapping(bytes32 => DataTypes.CampaignConfig) campaigns;
        /// @dev array of all campaign IDs
        bytes32[] campaignList;
        /// @dev quick lookup for campaign existence
        mapping(bytes32 => bool) isCampaign;
        /// @dev beneficiary => campaignId for reverse lookup
        mapping(address => bytes32) beneficiaryCampaign;
        
        // ============ User Positions ============
        /// @dev user => vault => position data
        mapping(address => mapping(address => DataTypes.UserPosition)) positions;
        /// @dev user => array of vaults they have positions in
        mapping(address => address[]) userVaults;
        /// @dev user => vault => array index for O(1) removal
        mapping(address => mapping(address => uint256)) userVaultIndex;
        
        // ============ User Preferences ============
        /// @dev user => vault => preference data
        mapping(address => mapping(address => DataTypes.UserPreference)) preferences;
        
        // ============ User Yield Tracking ============
        /// @dev user => vault => yield data
        mapping(address => mapping(address => DataTypes.UserYield)) userYields;
        
        // ============ Distribution Tracking ============
        /// @dev distributionId => distribution record
        mapping(uint256 => DataTypes.DistributionRecord) distributions;
        /// @dev counter for distribution IDs
        uint256 distributionCounter;
        /// @dev vault => array of distribution IDs
        mapping(address => uint256[]) vaultDistributions;
        
        // ============ Harvest Tracking ============
        /// @dev adapter => array of harvest results
        mapping(address => DataTypes.HarvestResult[]) harvestHistory;
        /// @dev adapter => last harvest timestamp
        mapping(address => uint40) lastHarvest;
        
        // ============ Protocol Configuration ============
        DataTypes.RiskParameters riskParams;
        DataTypes.FeeConfig feeConfig;
        DataTypes.ProtocolMetrics metrics;
        
        // ============ Pause States ============
        /// @dev global pause flag
        bool globalPaused;
        /// @dev vault => paused status
        mapping(address => bool) vaultPaused;
        /// @dev adapter => paused status
        mapping(address => bool) adapterPaused;
        /// @dev campaign => paused status
        mapping(bytes32 => bool) campaignPaused;
        
        // ============ Operational Pause Flags ============
        bool depositPaused;
        bool withdrawPaused;
        bool harvestPaused;
        bool campaignCreationPaused;
        
        // ============ Reentrancy Guard ============
        /// @dev reentrancy status (1 = not entered, 2 = entered)
        uint256 reentrancyStatus;
        
        // ============ Nonce Tracking ============
        /// @dev user => nonce for meta-transactions
        mapping(address => uint256) nonces;
        
        // ============ Campaign Staking ============
        /// @dev campaignId => staked amount
        mapping(bytes32 => uint256) campaignStakes;
        /// @dev user => campaignId => staked amount
        mapping(address => mapping(bytes32 => uint256)) userCampaignStakes;
        
        // ============ Upgrade Safety ============
        /// @dev implementation version for upgrade checks
        uint256 implementationVersion;
        /// @dev last upgrade timestamp
        uint40 lastUpgradeTime;
        
        // ============ Reserved Storage Slots ============
        /// @dev Reserved for future upgrades (50 slots)
        uint256[50] __gap;
    }

    // ============================================================
    // STORAGE ACCESSOR
    // ============================================================

    /**
     * @notice Get storage pointer to AppStorage
     * @return s Storage pointer
     * @dev Uses inline assembly for gas efficiency
     */
    function _getStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = GIVE_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    // ============================================================
    // STORAGE UTILITIES
    // ============================================================

    /**
     * @notice Check if vault exists
     * @param vault Vault address
     * @return exists True if vault exists
     */
    function _vaultExists(address vault) internal view returns (bool) {
        return _getStorage().isVault[vault];
    }

    /**
     * @notice Check if adapter exists
     * @param adapter Adapter address
     * @return exists True if adapter exists
     */
    function _adapterExists(address adapter) internal view returns (bool) {
        return _getStorage().isAdapter[adapter];
    }

    /**
     * @notice Check if campaign exists
     * @param campaignId Campaign ID
     * @return exists True if campaign exists
     */
    function _campaignExists(bytes32 campaignId) internal view returns (bool) {
        return _getStorage().isCampaign[campaignId];
    }

    /**
     * @notice Check if user has position in vault
     * @param user User address
     * @param vault Vault address
     * @return hasPosition True if position exists
     */
    function _hasPosition(address user, address vault) internal view returns (bool) {
        return _getStorage().positions[user][vault].shares > 0;
    }

    /**
     * @notice Get vault count
     * @return count Number of vaults
     */
    function _getVaultCount() internal view returns (uint256) {
        return _getStorage().vaultList.length;
    }

    /**
     * @notice Get adapter count
     * @return count Number of adapters
     */
    function _getAdapterCount() internal view returns (uint256) {
        return _getStorage().adapterList.length;
    }

    /**
     * @notice Get campaign count
     * @return count Number of campaigns
     */
    function _getCampaignCount() internal view returns (uint256) {
        return _getStorage().campaignList.length;
    }
}
