// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors
 * @dev Custom errors for the GIVE Protocol contracts
 */
library Errors {
    // === Vault Errors ===
    error VaultPaused();
    error InvestPaused();
    error HarvestPaused();
    error InsufficientCash();
    error InvalidAdapter();
    error AdapterNotSet();
    error CashBufferTooHigh();
    error InvalidCashBuffer();
    error ZeroAssets();
    error ZeroShares();
    error ExcessiveLoss(uint256 actual, uint256 max);
    error SlippageExceeded(uint256 actual, uint256 max);
    error InvalidReceiver();
    error InvalidOwner();
    error InsufficientAllowance();
    error InsufficientBalance();

    // === Adapter Errors ===
    error OnlyVault();
    error AdapterPaused();
    error InsufficientLiquidity();
    error InvalidInvestAmount();
    error InvalidDivestAmount();
    error ProtocolPaused();
    error OracleStale();
    error PriceDeviation();
    error InvalidAsset();
    error AdapterNotInitialized();

    // === Legacy Timelock Errors (Subject to removal after migration) ===
    error TimelockNotReady();
    error NoTimelockPending();
    error TimelockAlreadySet();

    // === Strategy Manager Errors ===
    error InvalidSlippageBps();
    error InvalidMaxLossBps();
    error ParameterOutOfRange();
    error UnauthorizedManager();
    error StrategyNotSet();
    error InvalidStrategy();

    // === Registry Errors ===
    error InvalidMetadataCid();
    error StrategyAlreadyExists();
    error StrategyNotFound();
    error CampaignNotFound();
    error CampaignNotActive();
    error StrategyInactive();
    error UnauthorizedCurator();
    error StakeTooLow(uint256 provided, uint256 minimumRequired);
    error StakeLocked();
    error StatusTransitionInvalid();
    error LockProfileNotAllowed();
    error WithdrawalLocked(uint256 unlockTimestamp);
    error EpochNotReady(uint256 nextEpochTimestamp);
    error InvalidBeneficiary();

    // === Access Control Errors ===
    error InvalidRole();
    error RoleAlreadyGranted();
    error RoleNotGranted();
    error CannotRenounceLastAdmin();

    // === General Errors ===
    error ZeroAddress();
    error InvalidAmount();
    error TransferFailed();
    error ContractPaused();
    error ReentrancyDetected();
    error InvalidConfiguration();
    error OperationNotAllowed();
    error TimelockNotExpired();
    error InvalidTimestamp();
    error ArrayLengthMismatch();
    error IndexOutOfBounds();
    error MathOverflow();
    error MathUnderflow();
    error DivisionByZero();

    // === User Preference Errors ===
    error InvalidAllocationPercentage(uint8 percentage);
    error UnauthorizedCaller(address caller);
}
