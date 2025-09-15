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
    address public protocolTreasury;
    uint256 public feeBps; // Fee in basis points (100 = 1%)
    uint256 public constant MAX_FEE_BPS = 1000; // 10% max fee
    uint256 public constant PROTOCOL_FEE_BPS = 250; // 2.5% protocol fee

    // User preferences for NGO allocation
    struct UserPreference {
        address selectedNGO;           // User's chosen NGO
        uint8 allocationPercentage;    // 50, 75, or 100
        uint256 lastUpdated;
    }

    mapping(address => UserPreference) public userPreferences;
    mapping(address => mapping(address => uint256)) public userAssetShares; // user => asset => shares
    mapping(address => uint256) public totalAssetShares; // asset => total shares
    mapping(address => address[]) public usersWithShares; // asset => array of users with shares
    mapping(address => mapping(address => bool)) public hasShares; // asset => user => has shares
    
    mapping(address => uint256) public totalDonated; // Total donated per asset
    mapping(address => uint256) public totalFeeCollected; // Total fees per asset
    mapping(address => uint256) public totalProtocolFees; // Total protocol fees per asset
    mapping(address => bool) public authorizedCallers; // Authorized to call distribute

    uint256 public totalDistributions;
    uint256 public totalNGOsSupported;
    
    // Valid allocation percentages
    uint8[] public validAllocations = [50, 75, 100];

    // === Events ===
    event DonationDistributed(
        address indexed asset, address indexed ngo, uint256 amount, uint256 feeAmount, uint256 distributionId
    );

    event UserYieldDistributed(
        address indexed user, address indexed asset, address indexed ngo, 
        uint256 ngoAmount, uint256 treasuryAmount, uint256 protocolAmount
    );

    event UserPreferenceUpdated(
        address indexed user, address indexed ngo, uint8 allocationPercentage
    );

    event UserSharesUpdated(
        address indexed user, address indexed asset, uint256 shares, uint256 totalShares
    );

    event FeeCollected(address indexed asset, address indexed recipient, uint256 amount);

    event ProtocolFeeCollected(address indexed asset, uint256 amount);

    event FeeConfigUpdated(
        address indexed oldRecipient, address indexed newRecipient, uint256 oldFeeBps, uint256 newFeeBps
    );

    event ProtocolTreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    event AuthorizedCallerUpdated(address indexed caller, bool authorized);

    event EmergencyWithdrawal(address indexed asset, address indexed recipient, uint256 amount);

    // === Constructor ===
    constructor(
        address _admin, 
        address _ngoRegistry, 
        address _feeRecipient, 
        address _protocolTreasury,
        uint256 _feeBps
    ) {
        if (_admin == address(0)) revert Errors.ZeroAddress();
        if (_ngoRegistry == address(0)) revert Errors.ZeroAddress();
        if (_feeRecipient == address(0)) revert Errors.ZeroAddress();
        if (_protocolTreasury == address(0)) revert Errors.ZeroAddress();
        if (_feeBps > MAX_FEE_BPS) revert Errors.InvalidConfiguration();

        ngoRegistry = NGORegistry(_ngoRegistry);
        feeRecipient = _feeRecipient;
        protocolTreasury = _protocolTreasury;
        feeBps = _feeBps;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(FEE_MANAGER_ROLE, _admin);
    }

    // === User Preference Functions ===

    /**
     * @dev Calculate distribution amounts for a user's yield
     * @param user The user address
     * @param userYield The total yield amount for the user
     * @return ngoAmount Amount going to the user's selected NGO
     * @return treasuryAmount Amount going to the treasury
     * @return protocolAmount Amount going to protocol fees
     */
    function calculateUserDistribution(address user, uint256 userYield) 
        public 
        view 
        returns (uint256 ngoAmount, uint256 treasuryAmount, uint256 protocolAmount) 
    {
        if (userYield == 0) {
            return (0, 0, 0);
        }

        // Calculate protocol fee first
        protocolAmount = (userYield * PROTOCOL_FEE_BPS) / 10_000;
        uint256 netYield = userYield - protocolAmount;

        UserPreference memory pref = userPreferences[user];
        
        // If user has no preference or NGO is not approved, all goes to treasury
        if (pref.selectedNGO == address(0) || !ngoRegistry.isApproved(pref.selectedNGO)) {
            ngoAmount = 0;
            treasuryAmount = netYield;
        } else {
            // Calculate NGO allocation based on user preference
            ngoAmount = (netYield * pref.allocationPercentage) / 100;
            treasuryAmount = netYield - ngoAmount;
        }
    }

    /**
     * @dev Distributes yield to users based on their preferences
     * @param asset The asset to distribute
     * @param totalYield The total yield amount to distribute
     */
    function distributeUserYield(address asset, uint256 totalYield) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        if (!authorizedCallers[msg.sender]) revert Errors.UnauthorizedCaller(msg.sender);
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (totalYield == 0) revert Errors.InvalidAmount();

        IERC20 token = IERC20(asset);
        uint256 balance = token.balanceOf(address(this));
        if (balance < totalYield) revert Errors.InsufficientBalance();

        uint256 totalShares = totalAssetShares[asset];
        if (totalShares == 0) return; // No users to distribute to

        // Get all users with shares and distribute proportionally
        // Note: In production, this would need pagination for gas efficiency
        _distributeToAllUsers(asset, totalYield, totalShares, token);
    }

    /**
     * @dev Internal function to distribute yield to all users
     */
    function _distributeToAllUsers(
        address asset, 
        uint256 totalYield, 
        uint256 totalShares, 
        IERC20 token
    ) internal {
        // This is a simplified implementation
        // In production, you'd need to track users and paginate
        // For now, we'll implement a batch distribution function
    }

    /**
     * @dev Distributes yield for a specific user
     * @param user The user address
     * @param asset The asset address
     * @param userYield The user's portion of yield
     */
    function distributeForUser(address user, address asset, uint256 userYield) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        if (!authorizedCallers[msg.sender]) revert Errors.UnauthorizedCaller(msg.sender);
        if (user == address(0) || asset == address(0)) revert Errors.ZeroAddress();
        if (userYield == 0) revert Errors.InvalidAmount();

        UserPreference memory pref = userPreferences[user];
        if (pref.selectedNGO == address(0)) {
            // User hasn't set preferences, send to treasury
            IERC20(asset).safeTransfer(feeRecipient, userYield);
            return;
        }

        if (!ngoRegistry.isNGOApproved(pref.selectedNGO)) {
            // NGO no longer approved, send to treasury
            IERC20(asset).safeTransfer(feeRecipient, userYield);
            return;
        }

        // Calculate protocol fee (always 1%)
        uint256 protocolFee = (userYield * PROTOCOL_FEE_BPS) / 10000;
        
        // Calculate NGO allocation based on user preference
        uint256 ngoAmount = (userYield * pref.allocationPercentage * (10000 - PROTOCOL_FEE_BPS)) / 1000000;
        
        // Remaining goes to treasury
        uint256 treasuryAmount = userYield - protocolFee - ngoAmount;

        IERC20 token = IERC20(asset);
        
        // Transfer protocol fee
        if (protocolFee > 0) {
            token.safeTransfer(protocolTreasury, protocolFee);
            totalProtocolFees[asset] += protocolFee;
            emit ProtocolFeeCollected(asset, protocolFee);
        }

        // Transfer to NGO
        if (ngoAmount > 0) {
            token.safeTransfer(pref.selectedNGO, ngoAmount);
            totalDonated[asset] += ngoAmount;
            ngoRegistry.recordDonation(pref.selectedNGO, ngoAmount);
        }

        // Transfer to treasury
        if (treasuryAmount > 0) {
            token.safeTransfer(feeRecipient, treasuryAmount);
            totalFeeCollected[asset] += treasuryAmount;
        }

        totalDistributions++;
    }

    /**
     * @dev Distributes yield to all users based on their preferences and vault shares
     * @param asset The asset to distribute
     * @param totalYield The total yield amount to distribute
     */
    function distributeToAllUsers(address asset, uint256 totalYield)
        external
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        if (!authorizedCallers[msg.sender]) revert Errors.UnauthorizedCaller(msg.sender);
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (totalYield == 0) revert Errors.InvalidAmount();

        uint256 totalShares = totalAssetShares[asset];
        if (totalShares == 0) {
            // No users have shares, fall back to legacy distribution
            address currentNGO = ngoRegistry.getCurrentNGO();
            if (currentNGO == address(0) || !ngoRegistry.isNGOApproved(currentNGO)) {
                // Send everything to fee recipient if no valid NGO
                IERC20(asset).safeTransfer(feeRecipient, totalYield);
                return totalYield;
            }
            
            // Calculate fee and donation
            uint256 feeAmount = (totalYield * feeBps) / 10_000;
            uint256 netDonation = totalYield - feeAmount;
            
            IERC20 assetToken = IERC20(asset);
            
            // Transfer to NGO
            if (netDonation > 0) {
                assetToken.safeTransfer(currentNGO, netDonation);
                totalDonated[asset] += netDonation;
                ngoRegistry.recordDonation(currentNGO, netDonation);
            }
            
            // Transfer fee
            if (feeAmount > 0) {
                assetToken.safeTransfer(feeRecipient, feeAmount);
                totalFeeCollected[asset] += feeAmount;
                emit FeeCollected(asset, feeRecipient, feeAmount);
            }
            
            totalDistributions++;
            emit DonationDistributed(asset, currentNGO, netDonation, feeAmount, totalDistributions);
            
            return totalYield;
        }

        // Get all users with shares for this asset
        address[] memory users = getUsersWithShares(asset);
        
        // Continue with user-based distribution
        
        uint256 totalNGOAmount = 0;
        uint256 totalTreasuryAmount = 0;
        uint256 totalProtocolAmount = 0;
        
        // Calculate distributions for each user
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 userShares = userAssetShares[user][asset];
            
            if (userShares > 0) {
                // Calculate user's proportional yield
                uint256 userYield = (totalYield * userShares) / totalShares;
                
                if (userYield > 0) {
                    (uint256 ngoAmount, uint256 treasuryAmount, uint256 protocolAmount) = 
                        calculateUserDistribution(user, userYield);
                    
                    totalNGOAmount += ngoAmount;
                    totalTreasuryAmount += treasuryAmount;
                    totalProtocolAmount += protocolAmount;
                    
                    // Emit event for this user's distribution
                    UserPreference memory pref = userPreferences[user];
                    emit UserYieldDistributed(
                        user, asset, pref.selectedNGO, ngoAmount, treasuryAmount, protocolAmount
                    );
                }
            }
        }
        
        IERC20 userDistributionToken = IERC20(asset);
        
        // Execute transfers
        if (totalProtocolAmount > 0) {
            userDistributionToken.safeTransfer(protocolTreasury, totalProtocolAmount);
            totalProtocolFees[asset] += totalProtocolAmount;
            emit ProtocolFeeCollected(asset, totalProtocolAmount);
        }
        
        if (totalNGOAmount > 0) {
            // Group by NGO and transfer
            _distributeToNGOs(asset, users, totalYield, totalShares);
        }
        
        if (totalTreasuryAmount > 0) {
            userDistributionToken.safeTransfer(feeRecipient, totalTreasuryAmount);
            totalFeeCollected[asset] += totalTreasuryAmount;
        }
        
        totalDistributions++;
        
        return totalNGOAmount + totalTreasuryAmount + totalProtocolAmount;
    }
    
    /**
     * @dev Internal function to distribute to NGOs efficiently
     */
    function _distributeToNGOs(address asset, address[] memory users, uint256 totalYield, uint256 totalShares) internal {
        IERC20 token = IERC20(asset);
        
        // Simple approach: transfer to each NGO individually
        // In production, you might want to batch transfers to the same NGO
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 userShares = userAssetShares[user][asset];
            
            if (userShares > 0) {
                UserPreference memory pref = userPreferences[user];
                if (pref.selectedNGO != address(0) && ngoRegistry.isNGOApproved(pref.selectedNGO)) {
                    uint256 userYield = (totalYield * userShares) / totalShares;
                    (uint256 ngoAmount,,) = calculateUserDistribution(user, userYield);
                    
                    if (ngoAmount > 0) {
                        token.safeTransfer(pref.selectedNGO, ngoAmount);
                        totalDonated[asset] += ngoAmount;
                        ngoRegistry.recordDonation(pref.selectedNGO, ngoAmount);
                    }
                }
            }
        }
    }

    // === Legacy Distribution Functions ===

    /**
     * @dev Legacy function - Distributes yield to the current NGO with optional fee
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
            revert Errors.UnauthorizedCaller(msg.sender);
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
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        if (asset == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.InvalidAmount();
        if (ngos.length == 0) revert Errors.InvalidConfiguration();

        // Verify all NGOs are approved
        for (uint256 i = 0; i < ngos.length; i++) {
            if (!ngoRegistry.isApproved(ngos[i])) {
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

    // === View Functions ===



    /**
     * @dev Gets user's shares for a specific asset
     * @param user The user address
     * @param asset The asset address
     * @return shares The user's share amount
     */
    function getUserAssetShares(address user, address asset) external view returns (uint256) {
        return userAssetShares[user][asset];
    }

    /**
     * @dev Gets total shares for an asset
     * @param asset The asset address
     * @return totalShares The total share amount
     */
    function getTotalAssetShares(address asset) external view returns (uint256) {
        return totalAssetShares[asset];
    }

    /**
     * @dev Gets valid allocation percentages
     * @return allocations Array of valid allocation percentages
     */
    function getValidAllocations() external view returns (uint8[] memory) {
        return validAllocations;
    }



    /**
     * @dev Gets all users who have shares for a specific asset
     * @param asset The asset address
     * @return users Array of user addresses with shares
     */
    function getUsersWithShares(address asset) public view returns (address[] memory) {
        return usersWithShares[asset];
    }



    // === Admin Functions ===

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
     * @dev Updates the protocol treasury address
     * @param _protocolTreasury New protocol treasury address
     */
    function setProtocolTreasury(address _protocolTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_protocolTreasury == address(0)) revert Errors.ZeroAddress();
        
        address oldTreasury = protocolTreasury;
        protocolTreasury = _protocolTreasury;
        
        emit ProtocolTreasuryUpdated(oldTreasury, _protocolTreasury);
    }

    /**
     * @dev Withdraws accumulated protocol fees
     * @param asset The asset to withdraw fees for
     */
    function withdrawProtocolFees(address asset) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (asset == address(0)) revert Errors.ZeroAddress();
        
        uint256 feeAmount = totalProtocolFees[asset];
        if (feeAmount == 0) revert Errors.InsufficientBalance();
        
        totalProtocolFees[asset] = 0;
        IERC20(asset).safeTransfer(protocolTreasury, feeAmount);
        
        emit ProtocolFeeCollected(asset, feeAmount);
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

    // === User Preference Functions ===
    
    /**
     * @notice Set user's NGO preference and allocation percentage
     * @param selectedNGO The NGO address to donate to
     * @param allocationPercentage Percentage of yield to donate (50, 75, or 100)
     */
    function setUserPreference(address selectedNGO, uint8 allocationPercentage) external {
        if (!ngoRegistry.isApproved(selectedNGO)) {
            revert Errors.NGONotApproved();
        }
        if (allocationPercentage != 50 && allocationPercentage != 75 && allocationPercentage != 100) {
            revert Errors.InvalidAllocationPercentage(allocationPercentage);
        }
        
        userPreferences[msg.sender] = UserPreference({
            selectedNGO: selectedNGO,
            allocationPercentage: allocationPercentage,
            lastUpdated: block.timestamp
        });
        
        emit UserPreferenceUpdated(msg.sender, selectedNGO, allocationPercentage);
    }
    
    /**
     * @notice Get user's current preference
     * @param user The user address
     * @return preference The user's current preference
     */
    function getUserPreference(address user) external view returns (UserPreference memory preference) {
        return userPreferences[user];
    }
    
    /**
     * @notice Update user's asset shares (called by vault)
     * @param user The user address
     * @param asset The asset address
     * @param newShares The new share amount
     */
    function updateUserShares(address user, address asset, uint256 newShares) external {
        if (!authorizedCallers[msg.sender]) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        
        uint256 oldShares = userAssetShares[user][asset];
        userAssetShares[user][asset] = newShares;
        
        // Update total shares
        totalAssetShares[asset] = totalAssetShares[asset] - oldShares + newShares;
        
        // Update users with shares tracking
        if (oldShares == 0 && newShares > 0) {
            // User is getting shares for the first time
            if (!hasShares[asset][user]) {
                usersWithShares[asset].push(user);
                hasShares[asset][user] = true;
            }
        } else if (oldShares > 0 && newShares == 0) {
            // User is removing all shares
            if (hasShares[asset][user]) {
                // Remove user from array
                address[] storage users = usersWithShares[asset];
                for (uint256 i = 0; i < users.length; i++) {
                    if (users[i] == user) {
                        users[i] = users[users.length - 1];
                        users.pop();
                        break;
                    }
                }
                hasShares[asset][user] = false;
            }
        }
        
        emit UserSharesUpdated(user, asset, newShares, totalAssetShares[asset]);
    }

    /**
     * @dev Fallback function to receive ETH (if needed for native token distributions)
     */
    receive() external payable {
        // Allow contract to receive ETH for native token distributions
    }
}
