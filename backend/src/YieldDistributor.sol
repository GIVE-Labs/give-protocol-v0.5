// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NGORegistry.sol";
import "./MorphImpactStaking.sol";

/**
 * @title YieldDistributor
 * @dev Automated yield distribution system for MorphImpact platform
 * Handles periodic yield distribution to NGOs based on staking activity
 */
contract YieldDistributor is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    
    uint256 public constant BASIS_POINTS = 10000;

    struct DistributionRound {
        uint256 roundNumber;
        uint256 totalYieldDistributed;
        uint256 distributionTime;
        uint256 stakersCount;
        mapping(address => uint256) yieldPerToken;
        mapping(address => mapping(address => uint256)) yieldPerNGO;
    }

    struct UserYieldInfo {
        uint256 lastClaimRound;
        mapping(address => uint256) unclaimedYield; // token => amount
    }

    NGORegistry public ngoRegistry;
    MorphImpactStaking public stakingContract;
    
    mapping(address => UserYieldInfo) public userYieldInfo;
    mapping(uint256 => DistributionRound) public distributionRounds;
    mapping(address => bool) public authorizedDistributors;
    
    uint256 public currentRound;
    uint256 public distributionInterval = 7 days;
    uint256 public lastDistributionTime;
    uint256 public minDistributionAmount = 0.001 ether;
    
    mapping(address => bool) public supportedTokens;
    address[] public tokenList;
    
    // Events
    event DistributionInitiated(
        uint256 indexed round,
        uint256 timestamp,
        address indexed distributor
    );
    
    event YieldDistributed(
        address indexed token,
        address indexed ngo,
        uint256 amount,
        uint256 indexed round
    );
    
    event UserYieldClaimed(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 indexed round
    );
    
    event DistributionIntervalUpdated(uint256 newInterval);
    event MinDistributionAmountUpdated(uint256 newAmount);
    event AuthorizedDistributorUpdated(address indexed distributor, bool authorized);
    event TokenSupportUpdated(address indexed token, bool supported);
    
    // Custom errors
    error InvalidAddress();
    error InvalidAmount();
    error DistributionTooFrequent();
    error NoYieldToDistribute();
    error UnauthorizedDistributor();
    error InvalidInterval();
    error TokenNotSupported();
    error RoundNotCompleted();
    error NoUnclaimedYield();
    
    constructor(address _ngoRegistry, address _stakingContract) Ownable(msg.sender) {
        if (_ngoRegistry == address(0) || _stakingContract == address(0)) revert InvalidAddress();
        
        ngoRegistry = NGORegistry(_ngoRegistry);
        stakingContract = MorphImpactStaking(_stakingContract);
        
        authorizedDistributors[msg.sender] = true;
        lastDistributionTime = block.timestamp;
    }
    
    /**
     * @dev Add or update authorized distributor
     * @param _distributor Address of the distributor
     * @param _authorized Whether to authorize or deauthorize
     */
    function setAuthorizedDistributor(
        address _distributor,
        bool _authorized
    ) external onlyOwner {
        if (_distributor == address(0)) revert InvalidAddress();
        
        authorizedDistributors[_distributor] = _authorized;
        emit AuthorizedDistributorUpdated(_distributor, _authorized);
    }
    
    /**
     * @dev Update distribution interval
     * @param _newInterval New interval in seconds
     */
    function setDistributionInterval(uint256 _newInterval) external onlyOwner {
        if (_newInterval < 1 hours) revert InvalidInterval();
        
        distributionInterval = _newInterval;
        emit DistributionIntervalUpdated(_newInterval);
    }
    
    /**
     * @dev Update minimum distribution amount
     * @param _newAmount New minimum amount
     */
    function setMinDistributionAmount(uint256 _newAmount) external onlyOwner {
        minDistributionAmount = _newAmount;
        emit MinDistributionAmountUpdated(_newAmount);
    }
    
    /**
     * @dev Add or remove supported token
     * @param _token Address of the token
     * @param _supported Whether to support or not
     */
    function setTokenSupport(
        address _token,
        bool _supported
    ) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        
        supportedTokens[_token] = _supported;
        
        if (_supported) {
            bool exists = false;
            for (uint256 i = 0; i < tokenList.length; i++) {
                if (tokenList[i] == _token) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                tokenList.push(_token);
            }
        } else {
            for (uint256 i = 0; i < tokenList.length; i++) {
                if (tokenList[i] == _token) {
                    tokenList[i] = tokenList[tokenList.length - 1];
                    tokenList.pop();
                    break;
                }
            }
        }
        
        emit TokenSupportUpdated(_token, _supported);
    }
    
    /**
     * @dev Initiate yield distribution round
     * Can be called by authorized distributors or when interval has passed
     */
    function initiateDistribution() external nonReentrant whenNotPaused {
        if (!authorizedDistributors[msg.sender] && 
            block.timestamp < lastDistributionTime + distributionInterval) {
            revert DistributionTooFrequent();
        }
        
        currentRound++;
        DistributionRound storage round = distributionRounds[currentRound];
        round.roundNumber = currentRound;
        round.distributionTime = block.timestamp;
        
        uint256 totalYieldThisRound = 0;
        uint256 activeStakers = 0;
        
        // Process each supported token
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            if (!supportedTokens[token]) continue;
            
            uint256 tokenYield = _distributeTokenYield(token, round);
            round.yieldPerToken[token] = tokenYield;
            totalYieldThisRound += tokenYield;
            
            if (tokenYield > 0) {
                activeStakers++;
            }
        }
        
        round.totalYieldDistributed = totalYieldThisRound;
        round.stakersCount = activeStakers;
        lastDistributionTime = block.timestamp;
        
        emit DistributionInitiated(currentRound, block.timestamp, msg.sender);
    }
    
    /**
     * @dev Internal function to distribute yield for a specific token
     * @param _token Address of the token
     * @param _round Distribution round
     * @return Total yield distributed for this token
     */
    function _distributeTokenYield(
        address _token,
        DistributionRound storage _round
    ) internal returns (uint256) {
        address[] memory verifiedNGOs = ngoRegistry.getNGOsByVerification(true);
        if (verifiedNGOs.length == 0) return 0;
        
        uint256 totalTokenYield = 0;
        
        // Calculate yield for each NGO based on staked amounts
        for (uint256 i = 0; i < verifiedNGOs.length; i++) {
            address ngo = verifiedNGOs[i];
            uint256 stakedForNGO = stakingContract.getTotalStakedForNGO(ngo, _token);
            
            if (stakedForNGO == 0) continue;
            
            uint256 ngoYield = _calculateNGOYield(_token, ngo, stakedForNGO);
            if (ngoYield < minDistributionAmount) continue;
            
            _round.yieldPerNGO[_token][ngo] = ngoYield;
            totalTokenYield += ngoYield;
            
            emit YieldDistributed(_token, ngo, ngoYield, currentRound);
        }
        
        return totalTokenYield;
    }
    
    /**
     * @dev Calculate yield for a specific NGO
     * @param _token Address of the token
     * @param _ngo Address of the NGO
     * @param _stakedAmount Amount staked for this NGO
     * @return Calculated yield amount
     */
    function _calculateNGOYield(
        address _token,
        address _ngo,
        uint256 _stakedAmount
    ) internal view returns (uint256) {
        // This is a simplified calculation - in reality, this would use actual yield data
        // For now, we'll use a mock calculation based on staking amounts and time
        
        uint256 totalStaked = stakingContract.totalStaked(_token);
        if (totalStaked == 0) return 0;
        
        // Mock calculation: 5% APY for demonstration
        uint256 apy = 500; // 5% in basis points
        uint256 timeElapsed = block.timestamp - lastDistributionTime;
        
        uint256 ngoShare = (_stakedAmount * BASIS_POINTS) / totalStaked;
        uint256 yieldPool = (totalStaked * apy * timeElapsed) / (BASIS_POINTS * 365 days);
        
        return (yieldPool * ngoShare) / BASIS_POINTS;
    }
    
    /**
     * @dev Claim user's unclaimed yield
     * @param _token Address of the token to claim yield for
     */
    function claimUserYield(address _token) external nonReentrant whenNotPaused {
        if (!supportedTokens[_token]) revert TokenNotSupported();
        
        UserYieldInfo storage userInfo = userYieldInfo[msg.sender];
        uint256 unclaimedAmount = userInfo.unclaimedYield[_token];
        
        if (unclaimedAmount == 0) revert NoUnclaimedYield();
        
        userInfo.unclaimedYield[_token] = 0;
        userInfo.lastClaimRound = currentRound;
        
        // Transfer yield to user
        IERC20(_token).safeTransfer(msg.sender, unclaimedAmount);
        
        emit UserYieldClaimed(msg.sender, _token, unclaimedAmount, currentRound);
    }
    
    /**
     * @dev Get user's unclaimed yield for a token
     * @param _user Address of the user
     * @param _token Address of the token
     * @return Unclaimed yield amount
     */
    function getUnclaimedYield(address _user, address _token) external view returns (uint256) {
        return userYieldInfo[_user].unclaimedYield[_token];
    }
    
    /**
     * @dev Get distribution round details
     * @param _round Round number
     * @return roundNumber Round number
     * @return totalYieldDistributed Total yield distributed
     * @return distributionTime Time of distribution
     * @return stakersCount Number of active stakers
     */
    function getDistributionRound(uint256 _round) external view returns (
        uint256 roundNumber,
        uint256 totalYieldDistributed,
        uint256 distributionTime,
        uint256 stakersCount
    ) {
        DistributionRound storage round = distributionRounds[_round];
        return (
            round.roundNumber,
            round.totalYieldDistributed,
            round.distributionTime,
            round.stakersCount
        );
    }
    
    /**
     * @dev Get yield distributed to an NGO in a specific round
     * @param _round Round number
     * @param _token Address of the token
     * @param _ngo Address of the NGO
     * @return Yield amount distributed
     */
    function getNGOYieldForRound(
        uint256 _round,
        address _token,
        address _ngo
    ) external view returns (uint256) {
        return distributionRounds[_round].yieldPerNGO[_token][_ngo];
    }
    
    /**
     * @dev Get current distribution status
     * @return canDistribute Whether distribution can be initiated
     * @return timeUntilNextDistribution Seconds until next distribution
     * @return totalSupportedTokens Number of supported tokens
     */
    function getDistributionStatus() external view returns (
        bool canDistribute,
        uint256 timeUntilNextDistribution,
        uint256 totalSupportedTokens
    ) {
        canDistribute = block.timestamp >= lastDistributionTime + distributionInterval;
        
        if (block.timestamp < lastDistributionTime + distributionInterval) {
            timeUntilNextDistribution = (lastDistributionTime + distributionInterval) - block.timestamp;
        } else {
            timeUntilNextDistribution = 0;
        }
        
        totalSupportedTokens = tokenList.length;
    }
    
    /**
     * @dev Get all supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }
    
    /**
     * @dev Emergency pause
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Emergency unpause
     */
    function unpause() external onlyOwner {
        _unpause();
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
}