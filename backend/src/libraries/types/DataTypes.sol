// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title DataTypes
 * @author GIVE Protocol
 * @notice Centralized type definitions for GIVE Protocol
 * @dev Following YOLO Protocol V1 pattern for type safety and reusability
 *      All protocol structs and enums defined here for consistency
 */
library DataTypes {
    // ============================================================
    // VAULT TYPES
    // ============================================================

    /**
     * @notice Vault configuration and metadata
     * @param asset Underlying asset address (USDC, WETH, etc.)
     * @param vaultToken ERC4626 vault token address
     * @param strategyManager Strategy manager contract address
     * @param campaignRegistry Campaign registry contract address
     * @param cashReserveBps Cash reserve in basis points (100 = 1%)
     * @param slippageToleranceBps Slippage tolerance (50 = 0.5%)
     * @param maxLossBps Maximum acceptable loss (50 = 0.5%)
     * @param totalAssets Total assets managed
     * @param totalShares Total vault shares issued
     * @param isActive Vault active status
     * @param isPaused Vault paused status
     * @param createdAt Creation timestamp
     */
    struct VaultConfig {
        address asset;
        address vaultToken;
        address strategyManager;
        address campaignRegistry;
        uint256 cashReserveBps;
        uint256 slippageToleranceBps;
        uint256 maxLossBps;
        uint256 totalAssets;
        uint256 totalShares;
        bool isActive;
        bool isPaused;
        uint40 createdAt;
    }

    // ============================================================
    // ADAPTER TYPES
    // ============================================================

    /**
     * @notice Yield adapter configuration
     * @param adapterAddress Adapter contract address
     * @param adapterType Type of yield strategy
     * @param targetProtocol External protocol address (Aave, Pendle, etc.)
     * @param vault Vault this adapter is attached to
     * @param allocationBps Allocation percentage (10000 = 100%)
     * @param totalInvested Total assets invested through this adapter
     * @param totalRealized Total profits realized
     * @param totalLoss Total losses incurred
     * @param isActive Adapter active status
     * @param lastHarvestTime Last yield harvest timestamp
     * @param createdAt Creation timestamp
     */
    struct AdapterConfig {
        address adapterAddress;
        AdapterType adapterType;
        address targetProtocol;
        address vault;
        uint256 allocationBps;
        uint256 totalInvested;
        uint256 totalRealized;
        uint256 totalLoss;
        bool isActive;
        uint40 lastHarvestTime;
        uint40 createdAt;
    }

    /**
     * @notice Supported yield adapter types
     */
    enum AdapterType {
        AAVE_V3,        // Aave V3 lending
        PENDLE_PT,      // Pendle Principal Tokens
        PENDLE_LP,      // Pendle Liquidity Provision
        EULER_V2,       // Euler V2 lending
        COMPOUND_V3,    // Compound V3
        MANUAL          // Manual strategy
    }

    // ============================================================
    // CAMPAIGN TYPES
    // ============================================================

    /**
     * @notice Campaign configuration and state
     * @param campaignId Unique campaign identifier
     * @param beneficiary Campaign beneficiary address
     * @param curator Curator who approved the campaign
     * @param name Campaign name
     * @param description Campaign description
     * @param metadataURI IPFS metadata URI
     * @param status Campaign status
     * @param totalReceived Total yield received
     * @param targetAmount Optional funding target
     * @param minStakeAmount Minimum stake required for submission
     * @param stakeAmount Amount staked by submitter
     * @param createdAt Creation timestamp
     * @param approvedAt Approval timestamp
     * @param completedAt Completion timestamp
     */
    struct CampaignConfig {
        bytes32 campaignId;
        address beneficiary;
        address curator;
        string name;
        string description;
        string metadataURI;
        CampaignStatus status;
        uint256 totalReceived;
        uint256 targetAmount;
        uint256 minStakeAmount;
        uint256 stakeAmount;
        uint40 createdAt;
        uint40 approvedAt;
        uint40 completedAt;
    }

    /**
     * @notice Campaign lifecycle status
     */
    enum CampaignStatus {
        PENDING,        // Awaiting curator approval
        APPROVED,       // Approved and accepting yield
        PAUSED,         // Temporarily paused
        COMPLETED,      // Target reached or manually completed
        REJECTED,       // Rejected by curator
        FADED           // Faded out due to inactivity
    }

    // ============================================================
    // USER TYPES
    // ============================================================

    /**
     * @notice User position in a vault
     * @param user User address
     * @param vault Vault address
     * @param asset Asset address
     * @param shares Vault shares held
     * @param lastDepositTime Last deposit timestamp
     * @param lockUntil Position locked until timestamp
     * @param totalDeposited Total assets deposited (for tracking)
     * @param totalWithdrawn Total assets withdrawn (for tracking)
     */
    struct UserPosition {
        address user;
        address vault;
        address asset;
        uint256 shares;
        uint40 lastDepositTime;
        uint40 lockUntil;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
    }

    /**
     * @notice User yield allocation preference
     * @param user User address
     * @param vault Vault address
     * @param selectedCampaign Campaign receiving yield
     * @param allocationBps Allocation percentage (5000 = 50%, 7500 = 75%, 10000 = 100%)
     * @param personalBeneficiary Address for personal yield (if < 100% to campaign)
     * @param lastUpdated Last preference update timestamp
     */
    struct UserPreference {
        address user;
        address vault;
        address selectedCampaign;
        uint256 allocationBps;
        address personalBeneficiary;
        uint40 lastUpdated;
    }

    /**
     * @notice User yield tracking
     * @param pendingYield Yield earned but not yet claimed
     * @param claimedYield Total yield claimed
     * @param rewardDebt Reward debt for staking-style accounting
     */
    struct UserYield {
        uint256 pendingYield;
        uint256 claimedYield;
        uint256 rewardDebt;
    }

    // ============================================================
    // DISTRIBUTION TYPES
    // ============================================================

    /**
     * @notice Yield distribution record
     * @param distributionId Unique distribution ID
     * @param vault Vault distributing yield
     * @param asset Asset being distributed
     * @param totalYield Total yield distributed
     * @param campaignYield Total to campaigns
     * @param personalYield Total to personal beneficiaries
     * @param protocolFee Protocol fee collected
     * @param userCount Number of users in distribution
     * @param timestamp Distribution timestamp
     */
    struct DistributionRecord {
        uint256 distributionId;
        address vault;
        address asset;
        uint256 totalYield;
        uint256 campaignYield;
        uint256 personalYield;
        uint256 protocolFee;
        uint256 userCount;
        uint40 timestamp;
    }

    /**
     * @notice Harvest result from yield adapter
     * @param adapter Adapter that harvested
     * @param profit Profit realized
     * @param loss Loss incurred
     * @param netProfit Net profit after loss
     * @param timestamp Harvest timestamp
     */
    struct HarvestResult {
        address adapter;
        uint256 profit;
        uint256 loss;
        uint256 netProfit;
        uint40 timestamp;
    }

    // ============================================================
    // PROTOCOL CONFIGURATION TYPES
    // ============================================================

    /**
     * @notice Protocol-wide risk parameters
     * @param maxCashReserveBps Maximum cash reserve (2000 = 20%)
     * @param maxSlippageBps Maximum slippage (1000 = 10%)
     * @param maxLossBps Maximum loss (500 = 5%)
     * @param minAdapterAllocation Minimum adapter allocation
     * @param maxAdapterAllocation Maximum adapter allocation
     * @param maxAdaptersPerVault Maximum adapters per vault
     */
    struct RiskParameters {
        uint256 maxCashReserveBps;
        uint256 maxSlippageBps;
        uint256 maxLossBps;
        uint256 minAdapterAllocation;
        uint256 maxAdapterAllocation;
        uint256 maxAdaptersPerVault;
    }

    /**
     * @notice Protocol fee configuration
     * @param protocolFeeBps Protocol fee in basis points (2000 = 20%)
     * @param treasuryAddress Treasury receiving fees
     * @param feeRecipient Alternative fee recipient
     */
    struct FeeConfig {
        uint256 protocolFeeBps;
        address treasuryAddress;
        address feeRecipient;
    }

    /**
     * @notice Protocol metrics and statistics
     * @param totalValueLocked Total value locked across all vaults
     * @param totalYieldGenerated Total yield generated
     * @param totalYieldDistributed Total yield distributed
     * @param totalProtocolFees Total protocol fees collected
     * @param totalCampaigns Total campaigns created
     * @param activeCampaigns Active campaigns count
     * @param totalUsers Total unique users
     */
    struct ProtocolMetrics {
        uint256 totalValueLocked;
        uint256 totalYieldGenerated;
        uint256 totalYieldDistributed;
        uint256 totalProtocolFees;
        uint256 totalCampaigns;
        uint256 activeCampaigns;
        uint256 totalUsers;
    }

    // ============================================================
    // CALLBACK & ACTION TYPES
    // ============================================================

    /**
     * @notice Actions that can be performed via callbacks
     */
    enum CallbackAction {
        DEPOSIT,            // User deposit
        WITHDRAW,           // User withdrawal
        HARVEST,            // Yield harvest
        REBALANCE,          // Portfolio rebalance
        EMERGENCY_WITHDRAW, // Emergency withdrawal
        LIQUIDATE           // Position liquidation
    }

    /**
     * @notice Callback data payload
     * @param action Action to perform
     * @param caller Original caller
     * @param data Encoded action-specific data
     */
    struct CallbackData {
        CallbackAction action;
        address caller;
        bytes data;
    }

    // ============================================================
    // CONSTANTS
    // ============================================================

    /// @notice Basis points denominator (10000 = 100%)
    uint256 internal constant BASIS_POINTS = 10000;

    /// @notice Maximum protocol fee (20%)
    uint256 internal constant MAX_PROTOCOL_FEE_BPS = 2000;

    /// @notice Minimum cash reserve (1%)
    uint256 internal constant MIN_CASH_RESERVE_BPS = 100;

    /// @notice Maximum cash reserve (30%)
    uint256 internal constant MAX_CASH_RESERVE_BPS = 3000;

    /// @notice Allocation options for users (50%, 75%, 100%)
    uint256 internal constant ALLOCATION_50_BPS = 5000;
    uint256 internal constant ALLOCATION_75_BPS = 7500;
    uint256 internal constant ALLOCATION_100_BPS = 10000;
}
