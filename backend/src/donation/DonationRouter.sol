// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NGORegistry.sol";
import "../utils/Errors.sol";

/**
 * @title DonationRouter
 * @dev Routes yield profits to approved NGOs with configurable fees
 * @notice Handles distribution of harvested yield to NGOs with flat split logic
 */
contract DonationRouter is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // === Roles ===
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    // === State Variables ===
    NGORegistry public immutable ngoRegistry;
    address public feeRecipient;
    uint256 public feeBps; // Fee in basis points (100 = 1%)
    uint256 public constant MAX_FEE_BPS = 1000; // 10% max fee

    mapping(address => uint256) public totalDonated; // Total donated per asset
    mapping(address => uint256) public totalFeeCollected; // Total fees per asset
    mapping(address => bool) public authorizedCallers; // Authorized to call distribute

    uint256 public totalDistributions;
    uint256 public totalNGOsSupported;

    // === Events ===
    event DonationDistributed(
        address indexed asset, address indexed ngo, uint256 amount, uint256 feeAmount, uint256 distributionId
    );

    event FeeCollected(address indexed asset, address indexed recipient, uint256 amount);

    event FeeConfigUpdated(
        address indexed oldRecipient, address indexed newRecipient, uint256 oldFeeBps, uint256 newFeeBps
    );

    event AuthorizedCallerUpdated(address indexed caller, bool authorized);

    event EmergencyWithdrawal(address indexed asset, address indexed recipient, uint256 amount);

    // === Constructor ===
    constructor(address _admin, address _ngoRegistry, address _feeRecipient, uint256 _feeBps) {
        if (_admin == address(0)) revert Errors.ZeroAddress();
        if (_ngoRegistry == address(0)) revert Errors.ZeroAddress();
        if (_feeRecipient == address(0)) revert Errors.ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        ngoRegistry = NGORegistry(_ngoRegistry);
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
    }

    // === Distribution Functions ===

    /**
     * @dev Distributes yield to the current NGO with optional fee
     * @param asset The asset to distribute
     * @param amount The total amount to distribute (before fees)
     * @return netDonation The amount donated to NGO after fees
     * @return feeAmount The fee amount collected
     */
    function distribute(address asset, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 netDonation, uint256 feeAmount)
    {
        if (!authorizedCallers[msg.sender]) {
            revert Errors.UnauthorizedCaller();
        }
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();

        address currentNGO = ngoRegistry.getCurrentNGO();
        if (currentNGO == address(0)) revert Errors.NoNGOConfigured();
        if (!ngoRegistry.isNGOApproved(currentNGO)) {
            revert Errors.NGONotApproved();
        }

        IERC20 token = IERC20(asset);
        uint256 balance = token.balanceOf(address(this));
        if (balance < amount) revert Errors.InsufficientBalance();

        // Calculate fee
        feeAmount = (amount * feeBps) / 10000;
        netDonation = amount - feeAmount;

        // Transfer fee to fee recipient
        if (feeAmount > 0) {
            token.safeTransfer(feeRecipient, feeAmount);
            totalFeeCollected[asset] += feeAmount;

            emit FeeCollected(asset, feeRecipient, feeAmount);
        }

        // Transfer donation to NGO
        if (netDonation > 0) {
            token.safeTransfer(currentNGO, netDonation);
            totalDonated[asset] += netDonation;

            // Record donation in registry
            ngoRegistry.recordDonation(currentNGO, netDonation);
        }

        totalDistributions++;

        emit DonationDistributed(asset, currentNGO, netDonation, feeAmount, totalDistributions);

        return (netDonation, feeAmount);
    }

    /**
     * @dev Distributes yield to multiple NGOs with equal split
     * @param asset The asset to distribute
     * @param amount The total amount to distribute
     * @param ngos Array of NGO addresses to distribute to
     * @return totalNetDonation Total amount donated after fees
     * @return feeAmount The fee amount collected
     */
    function distributeToMultiple(address asset, uint256 amount, address[] calldata ngos)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 totalNetDonation, uint256 feeAmount)
    {
        if (!authorizedCallers[msg.sender]) {
            revert Errors.UnauthorizedCaller();
        }
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();
        if (ngos.length == 0) revert Errors.InvalidConfiguration();

        // Verify all NGOs are approved
        for (uint256 i = 0; i < ngos.length; i++) {
            if (!ngoRegistry.isNGOApproved(ngos[i])) {
                revert Errors.NGONotApproved();
            }
        }

        IERC20 token = IERC20(asset);
        uint256 balance = token.balanceOf(address(this));
        if (balance < amount) revert Errors.InsufficientBalance();

        // Calculate fee
        feeAmount = (amount * feeBps) / 10000;
        totalNetDonation = amount - feeAmount;

        // Transfer fee to fee recipient
        if (feeAmount > 0) {
            token.safeTransfer(feeRecipient, feeAmount);
            totalFeeCollected[asset] += feeAmount;

            emit FeeCollected(asset, feeRecipient, feeAmount);
        }

        // Distribute equally among NGOs
        if (totalNetDonation > 0) {
            uint256 amountPerNGO = totalNetDonation / ngos.length;
            uint256 remainder = totalNetDonation % ngos.length;

            for (uint256 i = 0; i < ngos.length; i++) {
                uint256 donationAmount = amountPerNGO;

                // Add remainder to first NGO
                if (i == 0) {
                    donationAmount += remainder;
                }

                if (donationAmount > 0) {
                    token.safeTransfer(ngos[i], donationAmount);
                    totalDonated[asset] += donationAmount;

                    // Record donation in registry
                    ngoRegistry.recordDonation(ngos[i], donationAmount);

                    totalDistributions++;

                    emit DonationDistributed(
                        asset,
                        ngos[i],
                        donationAmount,
                        i == 0 ? feeAmount : 0, // Only emit fee for first NGO
                        totalDistributions
                    );
                }
            }
        }

        return (totalNetDonation, feeAmount);
    }

    // === Configuration Functions ===

    /**
     * @dev Updates fee configuration
     * @param _feeRecipient New fee recipient address
     * @param _feeBps New fee in basis points
     */
    function updateFeeConfig(address _feeRecipient, uint256 _feeBps) external onlyRole(FEE_MANAGER_ROLE) {
        if (_feeRecipient == address(0)) revert Errors.ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        address oldRecipient = feeRecipient;
        uint256 oldFeeBps = feeBps;

        feeRecipient = _feeRecipient;
        feeBps = _feeBps;

        emit FeeConfigUpdated(oldRecipient, _feeRecipient, oldFeeBps, _feeBps);
    }

    /**
     * @dev Authorizes or deauthorizes a caller to distribute funds
     * @param caller The address to authorize/deauthorize
     * @param authorized Whether to authorize or deauthorize
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyRole(VAULT_MANAGER_ROLE) {
        if (caller == address(0)) revert Errors.ZeroAddress();

        authorizedCallers[caller] = authorized;

        emit AuthorizedCallerUpdated(caller, authorized);
    }

    // === View Functions ===

    /**
     * @dev Returns distribution statistics
     * @param asset The asset to get stats for
     * @return totalDonatedAmount Total donated for this asset
     * @return totalFeesCollected Total fees collected for this asset
     * @return currentNGO Current NGO address
     * @return currentFeeBps Current fee in basis points
     */
    function getDistributionStats(address asset)
        external
        view
        returns (uint256 totalDonatedAmount, uint256 totalFeesCollected, address currentNGO, uint256 currentFeeBps)
    {
        return (totalDonated[asset], totalFeeCollected[asset], ngoRegistry.getCurrentNGO(), feeBps);
    }

    /**
     * @dev Calculates donation and fee amounts for a given total
     * @param amount The total amount to distribute
     * @return netDonation Amount that will go to NGO
     * @return feeAmount Amount that will go to fee recipient
     */
    function calculateDistribution(uint256 amount) external view returns (uint256 netDonation, uint256 feeAmount) {
        feeAmount = (amount * feeBps) / 10000;
        netDonation = amount - feeAmount;
        return (netDonation, feeAmount);
    }

    /**
     * @dev Checks if an address is authorized to call distribute
     * @param caller The address to check
     * @return Whether the address is authorized
     */
    function isAuthorizedCaller(address caller) external view returns (bool) {
        return authorizedCallers[caller];
    }

    /**
     * @dev Returns the current fee configuration
     * @return recipient Current fee recipient
     * @return bps Current fee in basis points
     * @return maxBps Maximum allowed fee in basis points
     */
    function getFeeConfig() external view returns (address recipient, uint256 bps, uint256 maxBps) {
        return (feeRecipient, feeBps, MAX_FEE_BPS);
    }

    // === Emergency Functions ===

    /**
     * @dev Emergency withdrawal of stuck tokens
     * @param asset The asset to withdraw
     * @param recipient The recipient address
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address asset, address recipient, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (recipient == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();

        IERC20 token = IERC20(asset);
        uint256 balance = token.balanceOf(address(this));
        if (balance < amount) revert Errors.InsufficientBalance();

        token.safeTransfer(recipient, amount);

        emit EmergencyWithdrawal(asset, recipient, amount);
    }

    /**
     * @dev Emergency pause of the router
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the router
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // === Receive Function ===

    /**
     * @dev Fallback function to receive ETH (if needed for native token distributions)
     */
    receive() external payable {
        // Allow contract to receive ETH for native token distributions
    }
}
