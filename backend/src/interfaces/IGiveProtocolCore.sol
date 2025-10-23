// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DataTypes} from "../libraries/types/DataTypes.sol";

/**
 * @title IGiveProtocolCore
 * @author GIVE Protocol
 * @notice Interface for GiveProtocolCore orchestrator
 * @dev Complete interface for all module functions
 */
interface IGiveProtocolCore {
    // ============================================================
    // EVENTS
    // ============================================================

    event ProtocolInitialized(address indexed treasury, address indexed guardian, uint256 protocolFeeBps);
    event ProtocolUpgraded(address indexed oldImplementation, address indexed newImplementation, uint256 version);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);
    event ProtocolFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    // ============================================================
    // INITIALIZATION
    // ============================================================

    function initialize(address treasury, address guardian, uint256 protocolFeeBps) external;

    // ============================================================
    // VAULT MODULE
    // ============================================================

    function registerVault(
        address vault,
        address asset,
        address strategyManager,
        address campaignRegistry,
        string calldata name,
        string calldata symbol,
        uint256 cashReserveBps
    ) external;

    function updateVaultParameters(
        address vault,
        uint256 cashReserveBps,
        uint256 slippageToleranceBps,
        uint256 maxLossBps
    ) external;

    function setVaultActive(address vault, bool isActive) external;
    function setVaultPaused(address vault, bool isPaused) external;
    function updateVaultMetrics(address vault, uint256 totalAssets, uint256 totalShares) external;
    
    function getVaultConfig(address vault) external view returns (DataTypes.VaultConfig memory);
    function isVaultOperational(address vault) external view returns (bool);
    function getAllVaults() external view returns (address[] memory);
    function getActiveVaults() external view returns (address[] memory);
    function getVaultTVL(address vault) external view returns (uint256);
    function calculateCashReserve(address vault) external view returns (uint256);

    // ============================================================
    // ADAPTER MODULE
    // ============================================================

    function registerAdapter(
        address adapter,
        DataTypes.AdapterType adapterType,
        string calldata targetProtocol,
        address vault
    ) external;

    function activateAdapter(address vault, address adapter, uint256 allocationBps) external;
    function deactivateAdapter(address vault, address adapter) external;
    function updateAdapterAllocation(address vault, address adapter, uint256 newAllocationBps) external;
    function invest(address vault, address adapter, uint256 amount) external returns (uint256 sharesReceived);
    function divest(address vault, address adapter, uint256 amount) external returns (uint256 assetsReceived);
    function harvest(address vault, address adapter) external returns (DataTypes.HarvestResult memory);
    function harvestAll(address vault) external returns (DataTypes.HarvestResult[] memory);
    function setAdapterPaused(address vault, address adapter, bool isPaused) external;
    
    function getAdapterConfig(address adapter) external view returns (DataTypes.AdapterConfig memory);
    function getVaultAdapters(address vault) external view returns (address[] memory);
    function getActiveVaultAdapters(address vault) external view returns (address[] memory);
    function getAdapterAllocation(address vault, address adapter) external view returns (uint256);
    function getTotalInvested(address vault, address adapter) external view returns (uint256);
    function isAdapterOperational(address vault, address adapter) external view returns (bool);

    // ============================================================
    // CAMPAIGN MODULE
    // ============================================================

    function submitCampaign(
        address beneficiary,
        string calldata name,
        string calldata description,
        string calldata metadataURI,
        uint256 targetAmount,
        uint256 stakeAmount
    ) external returns (bytes32 campaignId);

    function approveCampaign(bytes32 campaignId, address curator) external;
    function rejectCampaign(bytes32 campaignId, address curator, string calldata reason) external;
    function pauseCampaign(bytes32 campaignId) external;
    function resumeCampaign(bytes32 campaignId) external;
    function completeCampaign(bytes32 campaignId) external;
    function fadeCampaign(bytes32 campaignId) external;
    function recordFunding(bytes32 campaignId, uint256 amount) external;
    function withdrawCampaignFunds(bytes32 campaignId, uint256 amount, address recipient) external;
    function stakeCampaign(bytes32 campaignId, address staker, uint256 amount) external;
    function unstakeCampaign(bytes32 campaignId, address staker, uint256 amount) external;
    
    function getCampaignConfig(bytes32 campaignId) external view returns (DataTypes.CampaignConfig memory);
    function getCampaignByBeneficiary(address beneficiary) external view returns (bytes32);
    function getAllCampaigns() external view returns (bytes32[] memory);
    function getApprovedCampaigns() external view returns (bytes32[] memory);
    function getPendingCampaigns() external view returns (bytes32[] memory);
    function getCampaignStake(bytes32 campaignId) external view returns (uint256);
    function getUserCampaignStake(bytes32 campaignId, address staker) external view returns (uint256);
    function isCampaignOperational(bytes32 campaignId) external view returns (bool);

    // ============================================================
    // PAYOUT MODULE
    // ============================================================

    function setUserPreference(
        address user,
        address vault,
        address campaign,
        uint256 allocationBps,
        address personalBeneficiary
    ) external;

    function distributeYield(address vault, address asset, uint256 totalYield) external returns (uint256 distributionId);
    function claimYield(address user, address vault) external returns (uint256 claimed);
    function updateUserShares(address user, address vault, uint256 newShares, uint256 oldShares) external;
    
    function getUserPreference(address user, address vault) external view returns (DataTypes.UserPreference memory);
    function calculatePendingYield(address user, address vault) external view returns (uint256);
    function getPendingYield(address user, address vault) external view returns (uint256);
    function getClaimedYield(address user, address vault) external view returns (uint256);
    function getDistributionRecord(uint256 distributionId) external view returns (DataTypes.DistributionRecord memory);
    function getVaultDistributions(address vault) external view returns (uint256[] memory);
    function getUserDistributions(address user) external view returns (uint256[] memory);
    function getTotalDistributed(address vault) external view returns (uint256);
    function getUserYieldData(address user, address vault) external view returns (DataTypes.UserYield memory);

    // ============================================================
    // PROTOCOL CONFIGURATION
    // ============================================================

    function setTreasury(address newTreasury) external;
    function setGuardian(address newGuardian) external;
    function setProtocolFee(uint256 newFeeBps) external;
    function setPaused(bool isPaused) external;
    function setDepositPaused(bool isPaused) external;
    function setWithdrawPaused(bool isPaused) external;
    function setHarvestPaused(bool isPaused) external;
    function setCampaignPaused(bool isPaused) external;

    // ============================================================
    // PROTOCOL QUERIES
    // ============================================================

    function getTreasury() external view returns (address);
    function getGuardian() external view returns (address);
    function getFeeConfig() external view returns (DataTypes.FeeConfig memory);
    function getRiskParameters() external view returns (DataTypes.RiskParameters memory);
    function getProtocolMetrics() external view returns (DataTypes.ProtocolMetrics memory);
    function isGlobalPaused() external view returns (bool);
    function isDepositPaused() external view returns (bool);
    function isWithdrawPaused() external view returns (bool);
    function isHarvestPaused() external view returns (bool);
    function isCampaignActionsPaused() external view returns (bool);

    // ============================================================
    // UUPS UPGRADE
    // ============================================================

    function getImplementation() external view returns (address);
}
