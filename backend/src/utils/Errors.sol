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

    // === NGO Registry Errors ===
    error NGONotApproved();
    error NGOAlreadyApproved();
    error NGONotRegistered();
    error NGOAlreadyRegistered();
    error InvalidNGOAddress();
    error NGORemovalFailed();
    error UnauthorizedNGOManager();

    // === Donation Router Errors ===
    error InvalidDonationAmount();
    error DonationFailed();
    error NoNGOConfigured();
    error InvalidFeeRecipient();
    error FeeTooHigh();
    error InvalidFeeBps();
    error NoFundsToDistribute();
    error InvalidNGO();
    error DonationRouterPaused();

    // === Strategy Manager Errors ===
    error InvalidSlippageBps();
    error InvalidMaxLossBps();
    error ParameterOutOfRange();
    error UnauthorizedManager();
    error StrategyNotSet();
    error InvalidStrategy();

    // === Access Control Errors ===
    error UnauthorizedCaller();
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
}
