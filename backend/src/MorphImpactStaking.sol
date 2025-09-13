// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NGORegistry.sol";
import "./MockYieldVault.sol";

/**
 * @title MorphImpactStaking
 * @dev Main staking contract for the MorphImpact platform
 * Allows users to stake tokens for NGOs and receive yield while NGOs get the generated yield
 */
contract MorphImpactStaking is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    struct StakeInfo {
        uint256 amount;
        uint256 lockUntil;
        uint256 yieldContributionRate;
        uint256 totalYieldGenerated;
        uint256 totalYieldToNGO;
        bool isActive;
        uint256 stakeTime;
        uint256 lastYieldUpdate;
    }

    struct UserStake {
        mapping(address => mapping(address => StakeInfo)) stakes; // user => token => NGO => StakeInfo
        mapping(address => address[]) stakedNGOs; // token => NGOs
        mapping(address => mapping(address => bool)) hasStake; // token => NGO => bool
    }

    NGORegistry public ngoRegistry;
    MockYieldVault public yieldVault;

    mapping(address => UserStake) internal userStakes;
    mapping(address => uint256) public totalStaked; // token => total staked
    mapping(address => mapping(address => uint256)) public totalStakedForNGO; // token => NGO => amount
    mapping(address => mapping(address => uint256)) public totalYieldToNGO; // token => NGO => yield
    mapping(address => uint256) public vaultDepositTime; // token => when staking contract first deposited

    uint256 public constant MIN_YIELD_CONTRIBUTION = 5000; // 50%
    uint256 public constant MAX_YIELD_CONTRIBUTION = 10000; // 100%
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_LOCK_PERIOD = 30 days;
    uint256 public constant MAX_LOCK_PERIOD = 365 days;

    address[] public supportedTokens;
    mapping(address => bool) public isSupportedToken;

    // Events
    event Staked(
        address indexed user,
        address indexed ngo,
        address indexed token,
        uint256 amount,
        uint256 lockPeriod,
        uint256 yieldContributionRate
    );

    event Unstaked(
        address indexed user,
        address indexed ngo,
        address indexed token,
        uint256 amount,
        uint256 yieldToUser,
        uint256 yieldToNGO
    );

    event YieldDistributed(
        address indexed user, address indexed ngo, address indexed token, uint256 yieldToUser, uint256 yieldToNGO
    );

    event TokenSupportAdded(address indexed token);
    event TokenSupportRemoved(address indexed token);

    // Custom errors
    error UnsupportedToken();
    error InvalidNGO();
    error InvalidAmount();
    error InvalidLockPeriod();
    error InvalidYieldContribution();
    error StakeStillLocked();
    error NoActiveStake();
    error InsufficientBalance();
    error InvalidAddress();

    constructor(address _ngoRegistry, address _yieldVault) Ownable(msg.sender) {
        if (_ngoRegistry == address(0) || _yieldVault == address(0)) revert InvalidAddress();

        ngoRegistry = NGORegistry(_ngoRegistry);
        yieldVault = MockYieldVault(_yieldVault);
    }

    /**
     * @dev Add support for a token
     * @param _token Address of the token to support
     */
    function addSupportedToken(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();
        if (isSupportedToken[_token]) revert UnsupportedToken();

        isSupportedToken[_token] = true;
        supportedTokens.push(_token);

        emit TokenSupportAdded(_token);
    }

    /**
     * @dev Remove support for a token
     * @param _token Address of the token to remove
     */
    function removeSupportedToken(address _token) external onlyOwner {
        if (!isSupportedToken[_token]) revert UnsupportedToken();

        isSupportedToken[_token] = false;

        // Remove from supportedTokens array
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == _token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }

        emit TokenSupportRemoved(_token);
    }

    /**
     * @dev Stake tokens for an NGO
     * @param _ngo Address of the NGO
     * @param _token Address of the token to stake
     * @param _amount Amount to stake
     * @param _lockPeriod Lock period in seconds
     * @param _yieldContributionRate Yield contribution rate (basis points)
     */
    function stake(address _ngo, address _token, uint256 _amount, uint256 _lockPeriod, uint256 _yieldContributionRate)
        external
        nonReentrant
        whenNotPaused
    {
        if (!isSupportedToken[_token]) revert UnsupportedToken();
        if (!ngoRegistry.isVerifiedAndActive(_ngo)) revert InvalidNGO();
        if (_amount == 0) revert InvalidAmount();
        if (_lockPeriod < MIN_LOCK_PERIOD || _lockPeriod > MAX_LOCK_PERIOD) {
            revert InvalidLockPeriod();
        }
        if (_yieldContributionRate < MIN_YIELD_CONTRIBUTION || _yieldContributionRate > MAX_YIELD_CONTRIBUTION) {
            revert InvalidYieldContribution();
        }

        UserStake storage userStake = userStakes[msg.sender];
        StakeInfo storage stakeInfo = userStake.stakes[_token][_ngo];

        if (stakeInfo.isActive) {
            // Add to existing stake
            stakeInfo.amount += _amount;
            stakeInfo.lockUntil = block.timestamp + _lockPeriod;
        } else {
            // Create new stake
            stakeInfo.amount = _amount;
            stakeInfo.lockUntil = block.timestamp + _lockPeriod;
            stakeInfo.yieldContributionRate = _yieldContributionRate;
            stakeInfo.totalYieldGenerated = 0;
            stakeInfo.totalYieldToNGO = 0;
            stakeInfo.isActive = true;
            stakeInfo.stakeTime = block.timestamp;
            stakeInfo.lastYieldUpdate = block.timestamp;

            userStake.stakedNGOs[_token].push(_ngo);
            userStake.hasStake[_token][_ngo] = true;

            // Update NGO staker count
            ngoRegistry.updateStakerCount(_ngo, true);
        }

        totalStaked[_token] += _amount;
        totalStakedForNGO[_token][_ngo] += _amount;

        // Transfer tokens to this contract then to yield vault
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_token).forceApprove(address(yieldVault), _amount);
        yieldVault.deposit(_token, _amount);

        emit Staked(msg.sender, _ngo, _token, _amount, _lockPeriod, _yieldContributionRate);
    }

    /**
     * @dev Unstake tokens after lock period
     * @param _ngo Address of the NGO
     * @param _token Address of the token to unstake
     * @param _amount Amount to unstake (0 for full unstake)
     */
    function unstake(address _ngo, address _token, uint256 _amount) external nonReentrant whenNotPaused {
        UserStake storage userStake = userStakes[msg.sender];
        StakeInfo storage stakeInfo = userStake.stakes[_token][_ngo];

        if (!stakeInfo.isActive) revert NoActiveStake();
        if (block.timestamp < stakeInfo.lockUntil) revert StakeStillLocked();

        uint256 unstakeAmount = _amount == 0 ? stakeInfo.amount : _amount;
        if (stakeInfo.amount < unstakeAmount) revert InsufficientBalance();

        // Calculate and distribute yield
        (uint256 yieldToUser, uint256 yieldToNGO) = _calculateAndDistributeYield(msg.sender, _ngo, _token);

        // Update stake info
        stakeInfo.amount -= unstakeAmount;
        if (stakeInfo.amount == 0) {
            stakeInfo.isActive = false;
            _removeNGOFromUserList(msg.sender, _token, _ngo);
            ngoRegistry.updateStakerCount(_ngo, false);
        }

        totalStaked[_token] -= unstakeAmount;
        totalStakedForNGO[_token][_ngo] -= unstakeAmount;

        // Claim yield first (transfers yield to this contract)
        yieldVault.claimYield(_token);

        // Withdraw only the principal from the vault
        yieldVault.withdraw(_token, unstakeAmount);

        if (yieldToNGO > 0) {
            // Transfer yield to NGO
            IERC20(_token).safeTransfer(_ngo, yieldToNGO);
            totalYieldToNGO[_token][_ngo] += yieldToNGO;
            ngoRegistry.updateYieldReceived(_ngo, yieldToNGO);
        }

        IERC20(_token).safeTransfer(msg.sender, unstakeAmount + yieldToUser);

        emit Unstaked(msg.sender, _ngo, _token, unstakeAmount, yieldToUser, yieldToNGO);
    }

    /**
     * @dev Claim yield without unstaking
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     */
    function claimYield(address _ngo, address _token) external nonReentrant whenNotPaused {
        UserStake storage userStake = userStakes[msg.sender];
        StakeInfo storage stakeInfo = userStake.stakes[_token][_ngo];

        if (!stakeInfo.isActive) revert NoActiveStake();

        (uint256 yieldToUser, uint256 yieldToNGO) = _calculateAndDistributeYield(msg.sender, _ngo, _token);

        if (yieldToUser + yieldToNGO == 0) {
            // No yield to claim, just return without reverting
            return;
        }

        // Claim the yield from vault (transfers yield to this contract)
        yieldVault.claimYield(_token);

        if (yieldToNGO > 0) {
            IERC20(_token).safeTransfer(_ngo, yieldToNGO);
            totalYieldToNGO[_token][_ngo] += yieldToNGO;
            ngoRegistry.updateYieldReceived(_ngo, yieldToNGO);
        }

        if (yieldToUser > 0) {
            IERC20(_token).safeTransfer(msg.sender, yieldToUser);
        }

        emit YieldDistributed(msg.sender, _ngo, _token, yieldToUser, yieldToNGO);
    }

    /**
     * @dev Calculate and distribute yield for a stake
     * @param _user Address of the user
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     * @return yieldToUser Yield amount for user
     * @return yieldToNGO Yield amount for NGO
     */
    function _calculateAndDistributeYield(address _user, address _ngo, address _token)
        internal
        returns (uint256 yieldToUser, uint256 yieldToNGO)
    {
        StakeInfo storage stakeInfo = userStakes[_user].stakes[_token][_ngo];

        if (stakeInfo.amount == 0 || stakeInfo.lastYieldUpdate == 0) {
            return (0, 0);
        }

        // Calculate yield based on individual stake duration
        uint256 timeElapsed = block.timestamp - stakeInfo.lastYieldUpdate;
        if (timeElapsed == 0) {
            return (0, 0);
        }

        // Get vault's APY for this token
        uint256 apy = yieldVault.getAPY(_token);
        if (apy == 0) {
            return (0, 0);
        }

        // Calculate yield: amount * APY * timeElapsed / (BASIS_POINTS * SECONDS_PER_YEAR)
        uint256 yearlyYield = (stakeInfo.amount * apy) / BASIS_POINTS;
        uint256 yield = (yearlyYield * timeElapsed) / 365 days;

        yieldToNGO = (yield * stakeInfo.yieldContributionRate) / BASIS_POINTS;
        yieldToUser = yield - yieldToNGO;

        stakeInfo.totalYieldGenerated += yield;
        stakeInfo.totalYieldToNGO += yieldToNGO;
        stakeInfo.lastYieldUpdate = block.timestamp;
    }

    /**
     * @dev Get user's stake information
     * @param _user Address of the user
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     * @return stakeInfo Complete stake information
     */
    function getUserStake(address _user, address _ngo, address _token) external view returns (StakeInfo memory) {
        return userStakes[_user].stakes[_token][_ngo];
    }

    /**
     * @dev Get user's staked NGOs for a token
     * @param _user Address of the user
     * @param _token Address of the token
     * @return Array of NGO addresses
     */
    function getUserStakedNGOs(address _user, address _token) external view returns (address[] memory) {
        return userStakes[_user].stakedNGOs[_token];
    }

    /**
     * @dev Get total staked amount for an NGO
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     * @return Total staked amount
     */
    function getTotalStakedForNGO(address _ngo, address _token) external view returns (uint256) {
        return totalStakedForNGO[_token][_ngo];
    }

    /**
     * @dev Get total yield received by an NGO
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     * @return Total yield received
     */
    function getTotalYieldForNGO(address _ngo, address _token) external view returns (uint256) {
        return totalYieldToNGO[_token][_ngo];
    }

    /**
     * @dev Get supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @dev Check if user has active stake for NGO and token
     * @param _user Address of the user
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     * @return bool indicating if user has active stake
     */
    function hasActiveStake(address _user, address _ngo, address _token) external view returns (bool) {
        return userStakes[_user].stakes[_token][_ngo].isActive;
    }

    /**
     * @dev Get pending yield for a stake
     * @param _user Address of the user
     * @param _ngo Address of the NGO
     * @param _token Address of the token
     * @return pendingYield Total pending yield
     * @return yieldToUser User's share of pending yield
     * @return yieldToNGO NGO's share of pending yield
     */
    function getPendingYield(address _user, address _ngo, address _token)
        external
        view
        returns (uint256 pendingYield, uint256 yieldToUser, uint256 yieldToNGO)
    {
        StakeInfo memory stakeInfo = userStakes[_user].stakes[_token][_ngo];
        if (!stakeInfo.isActive || stakeInfo.lastYieldUpdate == 0) {
            return (0, 0, 0);
        }

        uint256 timeElapsed = block.timestamp - stakeInfo.lastYieldUpdate;
        if (timeElapsed == 0) {
            return (0, 0, 0);
        }

        // Get vault's APY for this token
        uint256 apy = yieldVault.getAPY(_token);
        if (apy == 0) {
            return (0, 0, 0);
        }

        // Calculate yield: amount * APY * timeElapsed / (BASIS_POINTS * SECONDS_PER_YEAR)
        uint256 yearlyYield = (stakeInfo.amount * apy) / BASIS_POINTS;
        uint256 yield = (yearlyYield * timeElapsed) / 365 days;

        yieldToNGO = (yield * stakeInfo.yieldContributionRate) / BASIS_POINTS;
        yieldToUser = yield - yieldToNGO;
        pendingYield = yield;
    }

    /**
     * @dev Remove NGO from user's staked NGOs list
     * @param _user Address of the user
     * @param _token Address of the token
     * @param _ngo Address of the NGO to remove
     */
    function _removeNGOFromUserList(address _user, address _token, address _ngo) internal {
        UserStake storage userStake = userStakes[_user];
        address[] storage ngos = userStake.stakedNGOs[_token];

        for (uint256 i = 0; i < ngos.length; i++) {
            if (ngos[i] == _ngo) {
                ngos[i] = ngos[ngos.length - 1];
                ngos.pop();
                break;
            }
        }

        userStake.hasStake[_token][_ngo] = false;
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
}
