// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../adapters/IYieldAdapter.sol";
import "../donation/DonationRouter.sol";
import "../utils/Errors.sol";

/**
 * @title GiveVault4626
 * @dev ERC-4626 vault for no-loss giving with yield routing to NGOs
 * @notice Users deposit assets, earn shares, while yield goes to approved NGOs
 */
contract GiveVault4626 is ERC4626, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // === Roles ===
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // === Constants ===
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_CASH_BUFFER_BPS = 2000; // 20%
    uint256 public constant MAX_SLIPPAGE_BPS = 1000; // 10%
    uint256 public constant MAX_LOSS_BPS = 500; // 5%

    // === State Variables ===
    IYieldAdapter public activeAdapter;
    address public donationRouter;
    
    uint256 public cashBufferBps = 100; // 1% default
    uint256 public slippageBps = 50; // 0.5% default
    uint256 public maxLossBps = 50; // 0.5% default
    
    bool public investPaused;
    bool public harvestPaused;
    
    uint256 private _lastHarvestTime;
    uint256 private _totalProfit;
    uint256 private _totalLoss;

    // === Events ===
    event AdapterUpdated(address indexed oldAdapter, address indexed newAdapter);
    event CashBufferUpdated(uint256 oldBps, uint256 newBps);
    event SlippageUpdated(uint256 oldBps, uint256 newBps);
    event MaxLossUpdated(uint256 oldBps, uint256 newBps);
    event DonationRouterUpdated(address indexed oldRouter, address indexed newRouter);
    event Harvest(uint256 profit, uint256 loss, uint256 donated);
    event InvestPaused(bool paused);
    event HarvestPaused(bool paused);
    event EmergencyWithdraw(uint256 amount);

    // === Constructor ===
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _admin
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        if (_admin == address(0)) revert Errors.ZeroAddress();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        
        _lastHarvestTime = block.timestamp;
    }

    // === Modifiers ===
    modifier whenInvestNotPaused() {
        if (investPaused) revert Errors.InvestPaused();
        _;
    }

    modifier whenHarvestNotPaused() {
        if (harvestPaused) revert Errors.HarvestPaused();
        _;
    }

    // === ERC4626 Overrides ===
    
    /**
     * @dev Returns total assets under management (cash + adapter assets)
     */
    function totalAssets() public view override returns (uint256) {
        uint256 cash = IERC20(asset()).balanceOf(address(this));
        uint256 adapterAssets = address(activeAdapter) != address(0) 
            ? activeAdapter.totalAssets() 
            : 0;
        return cash + adapterAssets;
    }

    /**
     * @dev Hook called after deposit to invest excess cash
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant whenNotPaused {
        super._deposit(caller, receiver, assets, shares);
        _investExcessCash();
    }

    /**
     * @dev Hook called before withdraw to ensure sufficient cash
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override nonReentrant whenNotPaused {
        _ensureSufficientCash(assets);
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // === Vault Management ===
    
    /**
     * @dev Sets the active yield adapter
     * @param _adapter The new adapter address
     */
    function setActiveAdapter(IYieldAdapter _adapter) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
    {
        if (address(_adapter) != address(0)) {
            if (_adapter.asset() != IERC20(asset())) revert Errors.InvalidAsset();
            if (_adapter.vault() != address(this)) revert Errors.InvalidAdapter();
        }
        
        address oldAdapter = address(activeAdapter);
        activeAdapter = _adapter;
        
        emit AdapterUpdated(oldAdapter, address(_adapter));
    }

    /**
     * @dev Sets the donation router address
     * @param _router The new donation router address
     */
    function setDonationRouter(address _router) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
    {
        if (_router == address(0)) revert Errors.ZeroAddress();
        
        address oldRouter = donationRouter;
        donationRouter = _router;
        
        emit DonationRouterUpdated(oldRouter, _router);
    }

    /**
     * @dev Sets the cash buffer percentage
     * @param _bps Basis points (100 = 1%)
     */
    function setCashBufferBps(uint256 _bps) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
    {
        if (_bps > MAX_CASH_BUFFER_BPS) revert Errors.CashBufferTooHigh();
        
        uint256 oldBps = cashBufferBps;
        cashBufferBps = _bps;
        
        emit CashBufferUpdated(oldBps, _bps);
    }

    /**
     * @dev Sets the slippage tolerance
     * @param _bps Basis points (50 = 0.5%)
     */
    function setSlippageBps(uint256 _bps) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
    {
        if (_bps > MAX_SLIPPAGE_BPS) revert Errors.InvalidSlippageBps();
        
        uint256 oldBps = slippageBps;
        slippageBps = _bps;
        
        emit SlippageUpdated(oldBps, _bps);
    }

    /**
     * @dev Sets the maximum loss tolerance
     * @param _bps Basis points (50 = 0.5%)
     */
    function setMaxLossBps(uint256 _bps) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
    {
        if (_bps > MAX_LOSS_BPS) revert Errors.InvalidMaxLossBps();
        
        uint256 oldBps = maxLossBps;
        maxLossBps = _bps;
        
        emit MaxLossUpdated(oldBps, _bps);
    }

    // === Pause Controls ===
    
    /**
     * @dev Pauses/unpauses investing
     */
    function setInvestPaused(bool _paused) 
        external 
        onlyRole(PAUSER_ROLE) 
    {
        investPaused = _paused;
        emit InvestPaused(_paused);
    }

    /**
     * @dev Pauses/unpauses harvesting
     */
    function setHarvestPaused(bool _paused) 
        external 
        onlyRole(PAUSER_ROLE) 
    {
        harvestPaused = _paused;
        emit HarvestPaused(_paused);
    }

    /**
     * @dev Emergency pause of all operations
     */
    function emergencyPause() 
        external 
        onlyRole(PAUSER_ROLE) 
    {
        _pause();
        investPaused = true;
        harvestPaused = true;
    }

    // === Yield Operations ===
    
    /**
     * @dev Harvests yield from adapter and routes profit to donation router
     * @return profit The amount of profit harvested
     * @return loss The amount of loss incurred
     */
    function harvest() 
        external 
        nonReentrant 
        whenHarvestNotPaused 
        returns (uint256 profit, uint256 loss) 
    {
        if (address(activeAdapter) == address(0)) revert Errors.AdapterNotSet();
        if (donationRouter == address(0)) revert Errors.InvalidConfiguration();
        
        // Harvest from adapter
        (profit, loss) = activeAdapter.harvest();
        
        // Update totals
        _totalProfit += profit;
        _totalLoss += loss;
        _lastHarvestTime = block.timestamp;
        
        // Atomically route profit to donation router
        uint256 donated = 0;
        if (profit > 0) {
            // Transfer profit to donation router
            IERC20(asset()).safeTransfer(donationRouter, profit);
            
            // Immediately distribute to NGOs
            (uint256 netDonation, uint256 feeAmount) = DonationRouter(payable(donationRouter)).distribute(
                asset(),
                profit
            );
            
            donated = netDonation + feeAmount; // Total amount processed
        }
        
        emit Harvest(profit, loss, donated);
    }

    /**
     * @dev Emergency withdrawal from adapter
     */
    function emergencyWithdrawFromAdapter() 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        returns (uint256 withdrawn) 
    {
        if (address(activeAdapter) == address(0)) revert Errors.AdapterNotSet();
        
        withdrawn = activeAdapter.emergencyWithdraw();
        emit EmergencyWithdraw(withdrawn);
    }

    // === Internal Functions ===
    
    /**
     * @dev Invests excess cash above buffer into adapter
     */
    function _investExcessCash() internal whenInvestNotPaused {
        if (address(activeAdapter) == address(0)) return;
        
        uint256 totalCash = IERC20(asset()).balanceOf(address(this));
        uint256 targetCash = (totalAssets() * cashBufferBps) / BASIS_POINTS;
        
        if (totalCash > targetCash) {
            uint256 excessCash = totalCash - targetCash;
            IERC20(asset()).safeTransfer(address(activeAdapter), excessCash);
            activeAdapter.invest(excessCash);
        }
    }

    /**
     * @dev Ensures sufficient cash for withdrawal, divesting from adapter if needed
     */
    function _ensureSufficientCash(uint256 needed) internal {
        uint256 currentCash = IERC20(asset()).balanceOf(address(this));
        
        if (currentCash >= needed) return;
        
        if (address(activeAdapter) == address(0)) revert Errors.InsufficientCash();
        
        uint256 shortfall = needed - currentCash;
        uint256 returned = activeAdapter.divest(shortfall);
        
        // Check if loss exceeds maximum allowed
        if (returned < shortfall) {
            uint256 loss = shortfall - returned;
            uint256 maxLoss = (shortfall * maxLossBps) / BASIS_POINTS;
            if (loss > maxLoss) {
                revert Errors.ExcessiveLoss(loss, maxLoss);
            }
        }
    }

    // === View Functions ===
    
    /**
     * @dev Returns current cash balance
     */
    function getCashBalance() external view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @dev Returns adapter assets
     */
    function getAdapterAssets() external view returns (uint256) {
        return address(activeAdapter) != address(0) 
            ? activeAdapter.totalAssets() 
            : 0;
    }

    /**
     * @dev Returns harvest statistics
     */
    function getHarvestStats() external view returns (
        uint256 totalProfit,
        uint256 totalLoss,
        uint256 lastHarvestTime
    ) {
        return (_totalProfit, _totalLoss, _lastHarvestTime);
    }

    /**
     * @dev Returns vault configuration
     */
    function getConfiguration() external view returns (
        uint256 cashBuffer,
        uint256 slippage,
        uint256 maxLoss,
        bool investPausedStatus,
        bool harvestPausedStatus
    ) {
        return (cashBufferBps, slippageBps, maxLossBps, investPaused, harvestPaused);
    }
}