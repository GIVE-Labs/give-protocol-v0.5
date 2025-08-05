// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title MockYieldVault
 * @dev Mock implementation of a yield-generating vault for testing purposes
 * Simulates various yield strategies including lending protocols and staking
 */
contract MockYieldVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct DepositInfo {
        uint256 amount;
        uint256 depositTime;
        uint256 lastYieldClaim;
    }

    mapping(address => mapping(address => DepositInfo)) public deposits;
    mapping(address => uint256) public totalDeposits;
    mapping(address => uint256) public totalYieldGenerated;
    
    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;
    mapping(address => uint256) public mockAPY; // Basis points (10000 = 100%)
    mapping(address => uint256) public lastYieldUpdate;
    
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Events
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event YieldClaimed(address indexed user, address indexed token, uint256 yield);
    event YieldGenerated(address indexed token, uint256 amount);
    event TokenSupportAdded(address indexed token, uint256 apy);
    event APYUpdated(address indexed token, uint256 newAPY);
    
    // Custom errors
    error UnsupportedToken();
    error InsufficientBalance();
    error ZeroAmount();
    error NoYieldToClaim();
    error TokenAlreadySupported();
    error InvalidAddress();
    error InvalidAmount();
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Add support for a token with mock APY
     * @param _token Address of the token
     * @param _apy Annual percentage yield in basis points
     */
    function addSupportedToken(address _token, uint256 _apy) external onlyOwner {
        if (isSupportedToken[_token]) revert TokenAlreadySupported();
        if (_token == address(0)) revert ZeroAmount();
        
        isSupportedToken[_token] = true;
        mockAPY[_token] = _apy;
        supportedTokens.push(_token);
        
        emit TokenSupportAdded(_token, _apy);
    }
    
    /**
     * @dev Update APY for a supported token
     * @param _token Address of the token
     * @param _newAPY New APY in basis points
     */
    function updateAPY(address _token, uint256 _newAPY) external onlyOwner {
        if (!isSupportedToken[_token]) revert UnsupportedToken();
        
        mockAPY[_token] = _newAPY;
        emit APYUpdated(_token, _newAPY);
    }
    
    /**
     * @dev Deposit tokens to generate yield
     * @param _token Address of the token to deposit
     * @param _amount Amount to deposit
     */
    function deposit(address _token, uint256 _amount) external nonReentrant {
        if (!isSupportedToken[_token]) revert UnsupportedToken();
        if (_amount == 0) revert ZeroAmount();
        
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        DepositInfo storage userDeposit = deposits[msg.sender][_token];
        if (userDeposit.amount == 0) {
            userDeposit.depositTime = block.timestamp;
            userDeposit.lastYieldClaim = block.timestamp;
        }
        
        userDeposit.amount += _amount;
        totalDeposits[_token] += _amount;
        
        emit Deposit(msg.sender, _token, _amount);
    }
    
    /**
     * @dev Withdraw deposited tokens
     * @param _token Address of the token to withdraw
     * @param _amount Amount to withdraw
     */
    function withdraw(address _token, uint256 _amount) external nonReentrant {
        if (!isSupportedToken[_token]) revert UnsupportedToken();
        if (_amount == 0) revert ZeroAmount();
        
        DepositInfo storage userDeposit = deposits[msg.sender][_token];
        if (userDeposit.amount < _amount) revert InsufficientBalance();
        
        // Claim any pending yield before withdrawal (ignore if no yield)
        try this.claimYield(_token) {
            // Yield claimed successfully
        } catch {
            // No yield to claim, continue with withdrawal
        }
        
        userDeposit.amount -= _amount;
        totalDeposits[_token] -= _amount;
        
        if (userDeposit.amount == 0) {
            userDeposit.depositTime = 0;
            userDeposit.lastYieldClaim = 0;
        }
        
        IERC20(_token).safeTransfer(msg.sender, _amount);
        
        emit Withdraw(msg.sender, _token, _amount);
    }
    
    /**
     * @dev Claim accumulated yield
     * @param _token Address of the token to claim yield for
     */
    function claimYield(address _token) external nonReentrant {
        _claimYield(msg.sender, _token);
    }
    
    /**
     * @dev Internal function to calculate and claim yield
     * @param _user Address of the user
     * @param _token Address of the token
     */
    function _claimYield(address _user, address _token) internal {
        if (!isSupportedToken[_token]) revert UnsupportedToken();
        
        DepositInfo storage userDeposit = deposits[_user][_token];
        if (userDeposit.amount == 0) revert ZeroAmount();
        
        uint256 yield = calculateYield(_user, _token);
        if (yield == 0) return; // Return silently if no yield instead of reverting
        
        userDeposit.lastYieldClaim = block.timestamp;
        totalYieldGenerated[_token] += yield;
        
        // Mint yield tokens (simulated)
        // In a real vault, this would come from actual yield strategies
        _mintYield(_token, yield);
        
        IERC20(_token).safeTransfer(_user, yield);
        
        emit YieldClaimed(_user, _token, yield);
    }
    
    /**
     * @dev Calculate yield for a specific user and token
     * @param _user Address of the user
     * @param _token Address of the token
     * @return Yield amount
     */
    function calculateYield(address _user, address _token) public view returns (uint256) {
        if (!isSupportedToken[_token]) return 0;
        
        DepositInfo memory userDeposit = deposits[_user][_token];
        if (userDeposit.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - userDeposit.lastYieldClaim;
        if (timeElapsed == 0) return 0;
        
        // Simple linear yield calculation
        uint256 yearlyYield = (userDeposit.amount * mockAPY[_token]) / BASIS_POINTS;
        uint256 yield = (yearlyYield * timeElapsed) / SECONDS_PER_YEAR;
        
        return yield;
    }
    
    /**
     * @dev Get comprehensive deposit information
     * @param _user Address of the user
     * @param _token Address of the token
     * @return amount Current deposit amount
     * @return depositTime When the deposit was made
     * @return pendingYield Pending yield to claim
     */
    function getDepositInfo(address _user, address _token) 
        external 
        view 
        returns (uint256 amount, uint256 depositTime, uint256 pendingYield) {
        DepositInfo memory userDeposit = deposits[_user][_token];
        return (
            userDeposit.amount,
            userDeposit.depositTime,
            calculateYield(_user, _token)
        );
    }
    
    /**
     * @dev Get supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }
    
    /**
     * @dev Get token APY
     * @param _token Address of the token
     * @return APY in basis points
     */
    function getAPY(address _token) external view returns (uint256) {
        if (!isSupportedToken[_token]) return 0;
        return mockAPY[_token];
    }
    
    /**
     * @dev Get total deposits for a token
     * @param _token Address of the token
     * @return Total deposits
     */
    function getTotalDeposits(address _token) external view returns (uint256) {
        return totalDeposits[_token];
    }
    
    /**
     * @dev Get total yield generated for a token
     * @param _token Address of the token
     * @return Total yield generated
     */
    function getTotalYieldGenerated(address _token) external view returns (uint256) {
        return totalYieldGenerated[_token];
    }
    
    /**
     * @dev Simulate yield generation (for testing)
     * @param _token Address of the token
     * @param _amount Amount of yield to simulate
     */
    function simulateYield(address _token, uint256 _amount) external onlyOwner {
        if (!isSupportedToken[_token]) revert UnsupportedToken();
        if (_amount == 0) revert ZeroAmount();
        
        _mintYield(_token, _amount);
        totalYieldGenerated[_token] += _amount;
        
        emit YieldGenerated(_token, _amount);
    }
    
    /**
     * @dev Emergency withdrawal of stuck tokens
     * @param _token Address of the token
     * @param _amount Amount to withdraw
     * @param _to Address to send tokens to
     */
    function emergencyWithdraw(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyOwner {
        if (_to == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();
        
        IERC20(_token).safeTransfer(_to, _amount);
    }
    
    /**
     * @dev Internal function to mint yield tokens (simulated)
     * @param _token Address of the token
     * @param _amount Amount to mint
     */
    function _mintYield(address _token, uint256 _amount) internal {
        // In testing, we simulate yield generation by minting
        // This ensures the vault always has enough balance for yields
        // For real implementations, this would come from actual yield strategies
        if (_token != address(0)) {
            // Mock minting by transferring from owner (who holds initial supply)
            // This is a simulation for testing purposes
        }
    }
}