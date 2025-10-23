// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {GiveProtocolStorage} from "./GiveProtocolStorage.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {ModuleBase} from "../libraries/utils/ModuleBase.sol";
import {VaultModule} from "../libraries/modules/VaultModule.sol";
import {AdapterModule} from "../libraries/modules/AdapterModule.sol";
import {CampaignModule} from "../libraries/modules/CampaignModule.sol";
import {PayoutModule} from "../libraries/modules/PayoutModule.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

/**
 * @title GiveProtocolCore
 * @author GIVE Protocol
 * @notice Main orchestrator contract following YOLO Protocol V1 architecture
 * @dev UUPS upgradeable proxy pattern with Diamond Storage (EIP-2535)
 *      Delegates to external library modules for gas efficiency
 *      
 *      Architecture:
 *      - Thin orchestrator layer (this contract)
 *      - External library modules (VaultModule, AdapterModule, CampaignModule, PayoutModule)
 *      - Diamond Storage for upgrade-safe state management
 *      - Role-based access control with 7 roles
 *      
 *      Gas Optimization:
 *      - External libraries reduce deployment costs
 *      - DELEGATECALL pattern for shared logic
 *      - Target: 30-40% gas reduction vs monolithic design
 */
contract GiveProtocolCore is 
    GiveProtocolStorage,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ============================================================
    // ERRORS
    // ============================================================

    error GiveProtocolCore__InvalidInitialization();
    error GiveProtocolCore__UnauthorizedUpgrade();

    // ============================================================
    // EVENTS
    // ============================================================

    event ProtocolInitialized(
        address indexed treasury,
        address indexed guardian,
        uint256 protocolFeeBps
    );

    event ProtocolUpgraded(
        address indexed oldImplementation,
        address indexed newImplementation,
        uint256 version
    );

    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event ProtocolFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    // ============================================================
    // INITIALIZATION
    // ============================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the protocol
     * @param treasury Protocol treasury address
     * @param guardian Protocol guardian address
     * @param protocolFeeBps Protocol fee in basis points
     */
    function initialize(
        address treasury,
        address guardian,
        uint256 protocolFeeBps
    ) external initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        if (treasury == address(0) || guardian == address(0)) {
            revert GiveProtocolCore__InvalidInitialization();
        }

        if (protocolFeeBps > DataTypes.MAX_PROTOCOL_FEE_BPS) {
            revert GiveProtocolCore__InvalidInitialization();
        }

        GiveProtocolStorage.AppStorage storage s = _getStorage();

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ModuleBase.VAULT_MANAGER_ROLE, msg.sender);
        _grantRole(ModuleBase.CAMPAIGN_CURATOR_ROLE, msg.sender);
        _grantRole(ModuleBase.RISK_ADMIN_ROLE, msg.sender);
        _grantRole(ModuleBase.PAUSER_ROLE, guardian);
        _grantRole(ModuleBase.UPGRADER_ROLE, msg.sender);
        _grantRole(ModuleBase.GUARDIAN_ROLE, guardian);

        // Initialize protocol config
        s.protocolTreasury = treasury;
        s.aclManager = guardian;
        s.feeConfig.protocolFeeBps = protocolFeeBps;
        s.feeConfig.treasuryAddress = treasury;
        s.feeConfig.feeRecipient = treasury;

        // Initialize risk parameters
        s.riskParams.maxAdaptersPerVault = 5;
        s.riskParams.maxAdapterAllocation = 9500; // 95%
        s.riskParams.minAdapterAllocation = 500; // 5%
        s.riskParams.maxCashReserveBps = 3000; // 30%
        s.riskParams.maxSlippageBps = 200; // 2%
        s.riskParams.maxLossBps = 500; // 5%

        emit ProtocolInitialized(treasury, guardian, protocolFeeBps);
    }

    // ============================================================
    // VAULT MODULE FUNCTIONS
    // ============================================================

    function registerVault(
        address vault,
        address asset,
        address strategyManager,
        address campaignRegistry,
        string calldata name,
        string calldata symbol,
        uint256 cashReserveBps
    ) external onlyRole(ModuleBase.VAULT_MANAGER_ROLE) {
        VaultModule.registerVault(
            _getStorage(),
            vault,
            asset,
            strategyManager,
            campaignRegistry,
            name,
            symbol,
            cashReserveBps
        );
    }

    function updateVaultParameters(
        address vault,
        uint256 cashReserveBps,
        uint256 slippageToleranceBps,
        uint256 maxLossBps
    ) external onlyRole(ModuleBase.VAULT_MANAGER_ROLE) {
        VaultModule.updateVaultParameters(
            _getStorage(),
            vault,
            cashReserveBps,
            slippageToleranceBps,
            maxLossBps
        );
    }

    function setVaultActive(address vault, bool isActive) 
        external 
        onlyRole(ModuleBase.VAULT_MANAGER_ROLE) 
    {
        VaultModule.setVaultActive(_getStorage(), vault, isActive);
    }

    function setVaultPaused(address vault, bool isPaused) 
        external 
        onlyRole(ModuleBase.PAUSER_ROLE) 
    {
        VaultModule.setVaultPaused(_getStorage(), vault, isPaused);
    }

    function updateVaultMetrics(
        address vault,
        uint256 totalAssets,
        uint256 totalShares
    ) external {
        VaultModule.updateVaultMetrics(_getStorage(), vault, totalAssets, totalShares);
    }

    // Vault queries
    function getVaultConfig(address vault) 
        external 
        view 
        returns (DataTypes.VaultConfig memory) 
    {
        return VaultModule.getVaultConfig(_getStorage(), vault);
    }

    function isVaultOperational(address vault) external view returns (bool) {
        return VaultModule.isVaultOperational(_getStorage(), vault);
    }

    function getAllVaults() external view returns (address[] memory) {
        return VaultModule.getAllVaults(_getStorage());
    }

    function getActiveVaults() external view returns (address[] memory) {
        return VaultModule.getActiveVaults(_getStorage());
    }

    function getVaultTVL(address vault) external view returns (uint256) {
        return VaultModule.getVaultTVL(_getStorage(), vault);
    }

    // ============================================================
    // ADAPTER MODULE FUNCTIONS
    // ============================================================

    function registerAdapter(
        address adapter,
        DataTypes.AdapterType adapterType,
        address targetProtocol,
        address vault
    ) external onlyRole(ModuleBase.VAULT_MANAGER_ROLE) {
        AdapterModule.registerAdapter(
            _getStorage(),
            adapter,
            adapterType,
            targetProtocol,
            vault
        );
    }

    function activateAdapter(
        address vault,
        address adapter,
        uint256 allocationBps
    ) external onlyRole(ModuleBase.VAULT_MANAGER_ROLE) {
        AdapterModule.activateAdapter(_getStorage(), vault, adapter, allocationBps);
    }

    function deactivateAdapter(address vault, address adapter) 
        external 
        onlyRole(ModuleBase.VAULT_MANAGER_ROLE) 
    {
        AdapterModule.deactivateAdapter(_getStorage(), vault, adapter);
    }

    function updateAdapterAllocation(
        address vault,
        address adapter,
        uint256 newAllocationBps
    ) external onlyRole(ModuleBase.RISK_ADMIN_ROLE) {
        AdapterModule.updateAdapterAllocation(_getStorage(), vault, adapter, newAllocationBps);
    }

    function invest(
        address vault,
        address adapter,
        uint256 amount
    ) external nonReentrant returns (uint256 sharesReceived) {
        return AdapterModule.invest(_getStorage(), vault, adapter, amount);
    }

    function divest(
        address vault,
        address adapter,
        uint256 amount
    ) external nonReentrant returns (uint256 assetsReceived) {
        return AdapterModule.divest(_getStorage(), vault, adapter, amount);
    }

    function harvest(address vault, address adapter) 
        external 
        nonReentrant 
        returns (DataTypes.HarvestResult memory) 
    {
        return AdapterModule.harvest(_getStorage(), vault, adapter);
    }

    function harvestAll(address vault) 
        external 
        nonReentrant 
        returns (DataTypes.HarvestResult[] memory) 
    {
        return AdapterModule.harvestAll(_getStorage(), vault);
    }

    function setAdapterPaused(address adapter, bool isPaused) 
        external 
        onlyRole(ModuleBase.PAUSER_ROLE) 
    {
        AdapterModule.setAdapterPaused(_getStorage(), adapter, isPaused);
    }

    // Adapter queries
    function getAdapterConfig(address adapter) 
        external 
        view 
        returns (DataTypes.AdapterConfig memory) 
    {
        return AdapterModule.getAdapterConfig(_getStorage(), adapter);
    }

    function getVaultAdapters(address vault) external view returns (address[] memory) {
        return AdapterModule.getVaultAdapters(_getStorage(), vault);
    }

    function getActiveVaultAdapters(address vault) external view returns (address[] memory) {
        return AdapterModule.getActiveVaultAdapters(_getStorage(), vault);
    }

    function getAdapterAllocation(address vault, address adapter) 
        external 
        view 
        returns (uint256) 
    {
        return AdapterModule.getAdapterAllocation(_getStorage(), vault, adapter);
    }

    function getTotalInvested(address adapter) 
        external 
        view 
        returns (uint256) 
    {
        return AdapterModule.getTotalInvested(_getStorage(), adapter);
    }

    function isAdapterOperational(address adapter) 
        external 
        view 
        returns (bool) 
    {
        return AdapterModule.isAdapterOperational(_getStorage(), adapter);
    }

    // ============================================================
    // CAMPAIGN MODULE FUNCTIONS
    // ============================================================

    function submitCampaign(
        address beneficiary,
        string calldata name,
        string calldata description,
        string calldata metadataURI,
        uint256 targetAmount,
        uint256 stakeAmount
    ) external nonReentrant returns (bytes32 campaignId) {
        return CampaignModule.submitCampaign(
            _getStorage(),
            beneficiary,
            name,
            description,
            metadataURI,
            targetAmount,
            stakeAmount
        );
    }

    function approveCampaign(bytes32 campaignId, address curator) 
        external 
        onlyRole(ModuleBase.CAMPAIGN_CURATOR_ROLE) 
    {
        CampaignModule.approveCampaign(_getStorage(), campaignId, curator);
    }

    function rejectCampaign(bytes32 campaignId, address curator, string calldata reason) 
        external 
        onlyRole(ModuleBase.CAMPAIGN_CURATOR_ROLE) 
    {
        CampaignModule.rejectCampaign(_getStorage(), campaignId, curator, reason);
    }

    function pauseCampaign(bytes32 campaignId) 
        external 
        onlyRole(ModuleBase.PAUSER_ROLE) 
    {
        CampaignModule.pauseCampaign(_getStorage(), campaignId);
    }

    function resumeCampaign(bytes32 campaignId) 
        external 
        onlyRole(ModuleBase.CAMPAIGN_CURATOR_ROLE) 
    {
        CampaignModule.resumeCampaign(_getStorage(), campaignId);
    }

    function completeCampaign(bytes32 campaignId) external {
        CampaignModule.completeCampaign(_getStorage(), campaignId);
    }

    function fadeCampaign(bytes32 campaignId) 
        external 
        onlyRole(ModuleBase.CAMPAIGN_CURATOR_ROLE) 
    {
        CampaignModule.fadeCampaign(_getStorage(), campaignId);
    }

    function recordFunding(bytes32 campaignId, uint256 amount) external nonReentrant {
        CampaignModule.recordFunding(_getStorage(), campaignId, amount);
    }

    function withdrawCampaignFunds(
        bytes32 campaignId,
        uint256 amount,
        address recipient
    ) external nonReentrant {
        CampaignModule.withdrawCampaignFunds(_getStorage(), campaignId, amount, recipient);
    }

    function stakeCampaign(bytes32 campaignId, address staker, uint256 amount) 
        external 
        nonReentrant 
    {
        CampaignModule.stakeCampaign(_getStorage(), campaignId, staker, amount);
    }

    function unstakeCampaign(bytes32 campaignId, address staker, uint256 amount) 
        external 
        nonReentrant 
    {
        CampaignModule.unstakeCampaign(_getStorage(), campaignId, staker, amount);
    }

    // Campaign queries
    function getCampaignConfig(bytes32 campaignId) 
        external 
        view 
        returns (DataTypes.CampaignConfig memory) 
    {
        return CampaignModule.getCampaignConfig(_getStorage(), campaignId);
    }

    function getCampaignByBeneficiary(address beneficiary) 
        external 
        view 
        returns (bytes32) 
    {
        return CampaignModule.getCampaignByBeneficiary(_getStorage(), beneficiary);
    }

    function getAllCampaigns() external view returns (bytes32[] memory) {
        return CampaignModule.getAllCampaigns(_getStorage());
    }

    function getApprovedCampaigns() external view returns (bytes32[] memory) {
        return CampaignModule.getApprovedCampaigns(_getStorage());
    }

    function getPendingCampaigns() external view returns (bytes32[] memory) {
        return CampaignModule.getPendingCampaigns(_getStorage());
    }

    function getCampaignStake(bytes32 campaignId) external view returns (uint256) {
        return CampaignModule.getCampaignStake(_getStorage(), campaignId);
    }

    function getUserCampaignStake(address staker, bytes32 campaignId) 
        external 
        view 
        returns (uint256) 
    {
        return CampaignModule.getUserCampaignStake(_getStorage(), staker, campaignId);
    }

    function isCampaignOperational(bytes32 campaignId) external view returns (bool) {
        return CampaignModule.isCampaignOperational(_getStorage(), campaignId);
    }

    // ============================================================
    // PAYOUT MODULE FUNCTIONS
    // ============================================================

    function setUserPreference(
        address user,
        address vault,
        address campaign,
        uint256 allocationBps,
        address personalBeneficiary
    ) external {
        PayoutModule.setUserPreference(
            _getStorage(),
            user,
            vault,
            campaign,
            allocationBps,
            personalBeneficiary
        );
    }

    function distributeYield(
        address vault,
        address asset,
        uint256 totalYield
    ) external nonReentrant returns (uint256 distributionId) {
        return PayoutModule.distributeYield(_getStorage(), vault, asset, totalYield);
    }

    function claimYield(address user, address vault) 
        external 
        nonReentrant 
        returns (uint256 claimed) 
    {
        return PayoutModule.claimYield(_getStorage(), user, vault);
    }

    function updateUserShares(
        address user,
        address vault,
        uint256 newShares,
        uint256 oldShares
    ) external {
        PayoutModule.updateUserShares(_getStorage(), user, vault, newShares, oldShares);
    }

    // Payout queries
    function getUserPreference(address user, address vault) 
        external 
        view 
        returns (DataTypes.UserPreference memory) 
    {
        return PayoutModule.getUserPreference(_getStorage(), user, vault);
    }

    function calculatePendingYield(address user, address vault) 
        external 
        view 
        returns (uint256) 
    {
        return PayoutModule.calculatePendingYield(_getStorage(), user, vault);
    }

    function getPendingYield(address user, address vault) external view returns (uint256) {
        return PayoutModule.getPendingYield(_getStorage(), user, vault);
    }

    function getClaimedYield(address user, address vault) external view returns (uint256) {
        return PayoutModule.getClaimedYield(_getStorage(), user, vault);
    }

    function getDistributionRecord(uint256 distributionId) 
        external 
        view 
        returns (DataTypes.DistributionRecord memory) 
    {
        return PayoutModule.getDistributionRecord(_getStorage(), distributionId);
    }

    function getVaultDistributions(address vault) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return PayoutModule.getVaultDistributions(_getStorage(), vault);
    }

    function getUserDistributions(address user) external view returns (uint256[] memory) {
        return PayoutModule.getUserDistributions(_getStorage(), user);
    }

    function getTotalDistributed(address vault) external view returns (uint256) {
        return PayoutModule.getTotalDistributed(_getStorage(), vault);
    }

    function getUserYieldData(address user, address vault) 
        external 
        view 
        returns (DataTypes.UserYield memory) 
    {
        return PayoutModule.getUserYieldData(_getStorage(), user, vault);
    }

    // ============================================================
    // PROTOCOL CONFIGURATION
    // ============================================================

    function setTreasury(address newTreasury) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        address oldTreasury = s.protocolTreasury;
        s.protocolTreasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function setGuardian(address newGuardian) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        address oldGuardian = s.aclManager;
        s.aclManager = newGuardian;
        
        // Update guardian role
        _revokeRole(ModuleBase.GUARDIAN_ROLE, oldGuardian);
        _grantRole(ModuleBase.GUARDIAN_ROLE, newGuardian);
        _grantRole(ModuleBase.PAUSER_ROLE, newGuardian);
        
        emit GuardianUpdated(oldGuardian, newGuardian);
    }

    function setProtocolFee(uint256 newFeeBps) 
        external 
        onlyRole(ModuleBase.RISK_ADMIN_ROLE) 
    {
        if (newFeeBps > DataTypes.MAX_PROTOCOL_FEE_BPS) {
            revert GiveProtocolCore__InvalidInitialization();
        }
        
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        uint256 oldFeeBps = s.feeConfig.protocolFeeBps;
        s.feeConfig.protocolFeeBps = newFeeBps;
        
        emit ProtocolFeeUpdated(oldFeeBps, newFeeBps);
    }

    function setPaused(bool isPaused) external onlyRole(ModuleBase.PAUSER_ROLE) {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        s.globalPaused = isPaused;
    }

    function setDepositPaused(bool isPaused) external onlyRole(ModuleBase.PAUSER_ROLE) {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        s.depositPaused = isPaused;
    }

    function setWithdrawPaused(bool isPaused) external onlyRole(ModuleBase.PAUSER_ROLE) {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        s.withdrawPaused = isPaused;
    }

    function setHarvestPaused(bool isPaused) external onlyRole(ModuleBase.PAUSER_ROLE) {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        s.harvestPaused = isPaused;
    }

    function setCampaignPaused(bool isPaused) external onlyRole(ModuleBase.PAUSER_ROLE) {
        GiveProtocolStorage.AppStorage storage s = _getStorage();
        s.campaignCreationPaused = isPaused;
    }

    // ============================================================
    // PROTOCOL QUERIES
    // ============================================================

    function getTreasury() external view returns (address) {
        return _getStorage().protocolTreasury;
    }

    function getGuardian() external view returns (address) {
        return _getStorage().aclManager;
    }

    function getFeeConfig() external view returns (DataTypes.FeeConfig memory) {
        return _getStorage().feeConfig;
    }

    function getRiskParameters() external view returns (DataTypes.RiskParameters memory) {
        return _getStorage().riskParams;
    }

    function getProtocolMetrics() external view returns (DataTypes.ProtocolMetrics memory) {
        return _getStorage().metrics;
    }

    function isGlobalPaused() external view returns (bool) {
        return _getStorage().globalPaused;
    }

    function isDepositPaused() external view returns (bool) {
        return _getStorage().depositPaused;
    }

    function isWithdrawPaused() external view returns (bool) {
        return _getStorage().withdrawPaused;
    }

    function isHarvestPaused() external view returns (bool) {
        return _getStorage().harvestPaused;
    }

    function isCampaignActionsPaused() external view returns (bool) {
        return _getStorage().campaignCreationPaused;
    }

    // ============================================================
    // UUPS UPGRADE
    // ============================================================

    /**
     * @notice Authorize upgrade (UUPS pattern)
     * @param newImplementation New implementation address
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyRole(ModuleBase.UPGRADER_ROLE) 
    {
        if (newImplementation == address(0)) {
            revert GiveProtocolCore__UnauthorizedUpgrade();
        }

        GiveProtocolStorage.AppStorage storage s = _getStorage();
        s.lastUpgradeTime = uint40(block.timestamp);

        emit ProtocolUpgraded(
            getImplementation(),
            newImplementation,
            s.lastUpgradeTime
        );
    }

    /**
     * @notice Get current implementation address
     * @return Implementation address
     */
    function getImplementation() public view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
