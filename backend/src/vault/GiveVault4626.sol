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
import "../utils/IWETH.sol";

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
    address public wrappedNative; // Optional: if set and equals asset(), enables ETH convenience methods

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
    event WrappedNativeSet(address indexed token);

    // === Constructor ===
    constructor(IERC20 _asset, string memory _name, string memory _symbol, address _admin)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {
        if (_admin == address(0)) revert Errors.ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);

        _lastHarvestTime = block.timestamp;
    }

    // Receive only allowed for unwrapping WETH
    receive() external payable {
        if (wrappedNative == address(0) || msg.sender != wrappedNative) {
            revert Errors.InvalidConfiguration();
        }
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
        uint256 adapterAssets = address(activeAdapter) != address(0) ? activeAdapter.totalAssets() : 0;
        return cash + adapterAssets;
    }

    /**
     * @dev Deposit assets and mint shares with reentrancy protection
     */
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        return super.deposit(assets, receiver);
    }

    /**
     * @dev Mint shares for assets with reentrancy protection
     */
    function mint(uint256 shares, address receiver) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        return super.mint(shares, receiver);
    }

    /**
     * @dev Withdraw assets by burning shares with reentrancy protection
     */
    function withdraw(uint256 assets, address receiver, address owner) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @dev Redeem shares for assets with reentrancy protection
     */
    function redeem(uint256 shares, address receiver, address owner) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256) 
    {
        return super.redeem(shares, receiver, owner);
    }

    /**
     * @dev Hook called after deposit to invest excess cash and update user shares
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        whenNotPaused
    {
        super._deposit(caller, receiver, assets, shares);
        
        // Update user shares in donation router for yield distribution
        if (donationRouter != address(0)) {
            DonationRouter(payable(donationRouter)).updateUserShares(receiver, asset(), balanceOf(receiver));
        }
        
        _investExcessCash();
    }

    /**
     * @dev Internal function to handle post-deposit logic
     */
    function _afterDeposit(address caller, address receiver, uint256 assets, uint256 shares) internal {
        // Update user shares in donation router for yield distribution
        if (donationRouter != address(0)) {
            DonationRouter(payable(donationRouter)).updateUserShares(receiver, asset(), balanceOf(receiver));
        }
        
        _investExcessCash();
    }

    /**
     * @dev Hook called before withdraw to ensure sufficient cash and update user shares
     */
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
        whenNotPaused
    {
        _ensureSufficientCash(assets);
        super._withdraw(caller, receiver, owner, assets, shares);
        
        // Update user shares in donation router after withdrawal
        if (donationRouter != address(0)) {
            DonationRouter(payable(donationRouter)).updateUserShares(owner, asset(), balanceOf(owner));
        }
    }

    // === Vault Management ===
    /**
     * @dev Set wrapped native token address (e.g., WETH). Must match vault asset.
     */
    function setWrappedNative(address _wrapped) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_wrapped == address(0)) revert Errors.ZeroAddress();
        if (_wrapped != address(asset())) revert Errors.InvalidConfiguration();
        wrappedNative = _wrapped;
        emit WrappedNativeSet(_wrapped);
    }

    /**
     * @dev Sets the active yield adapter
     * @param _adapter The new adapter address
     */
    function setActiveAdapter(IYieldAdapter _adapter) external onlyRole(VAULT_MANAGER_ROLE) {
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
    function setDonationRouter(address _router) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_router == address(0)) revert Errors.ZeroAddress();

        address oldRouter = donationRouter;
        donationRouter = _router;

        emit DonationRouterUpdated(oldRouter, _router);
    }

    /**
     * @dev Sets the cash buffer percentage
     * @param _bps Basis points (100 = 1%)
     */
    function setCashBufferBps(uint256 _bps) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_bps > MAX_CASH_BUFFER_BPS) revert Errors.CashBufferTooHigh();

        uint256 oldBps = cashBufferBps;
        cashBufferBps = _bps;

        emit CashBufferUpdated(oldBps, _bps);
    }

    /**
     * @dev Sets the slippage tolerance
     * @param _bps Basis points (50 = 0.5%)
     */
    function setSlippageBps(uint256 _bps) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_bps > MAX_SLIPPAGE_BPS) revert Errors.InvalidSlippageBps();

        uint256 oldBps = slippageBps;
        slippageBps = _bps;

        emit SlippageUpdated(oldBps, _bps);
    }

    /**
     * @dev Sets the maximum loss tolerance
     * @param _bps Basis points (50 = 0.5%)
     */
    function setMaxLossBps(uint256 _bps) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_bps > MAX_LOSS_BPS) revert Errors.InvalidMaxLossBps();

        uint256 oldBps = maxLossBps;
        maxLossBps = _bps;

        emit MaxLossUpdated(oldBps, _bps);
    }

    // === Pause Controls ===

    /**
     * @dev Pauses/unpauses investing
     */
    function setInvestPaused(bool _paused) external onlyRole(PAUSER_ROLE) {
        investPaused = _paused;
        emit InvestPaused(_paused);
    }

    /**
     * @dev Pauses/unpauses harvesting
     */
    function setHarvestPaused(bool _paused) external onlyRole(PAUSER_ROLE) {
        harvestPaused = _paused;
        emit HarvestPaused(_paused);
    }

    /**
     * @dev Emergency pause of all operations
     */
    function emergencyPause() external onlyRole(PAUSER_ROLE) {
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
    function harvest() external nonReentrant whenHarvestNotPaused returns (uint256 profit, uint256 loss) {
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

            // Distribute yield to all users based on their preferences
            donated = DonationRouter(payable(donationRouter)).distributeToAllUsers(asset(), profit);
        }

        emit Harvest(profit, loss, donated);
    }

    /**
     * @dev Emergency withdrawal from adapter
     */
    function emergencyWithdrawFromAdapter() external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 withdrawn) {
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
        return address(activeAdapter) != address(0) ? activeAdapter.totalAssets() : 0;
    }

    /**
     * @dev Returns harvest statistics
     */
    function getHarvestStats()
        external
        view
        returns (uint256 totalProfit, uint256 totalLoss, uint256 lastHarvestTime)
    {
        return (_totalProfit, _totalLoss, _lastHarvestTime);
    }

    /**
     * @dev Returns vault configuration
     */
    function getConfiguration()
        external
        view
        returns (
            uint256 cashBuffer,
            uint256 slippage,
            uint256 maxLoss,
            bool investPausedStatus,
            bool harvestPausedStatus
        )
    {
        return (cashBufferBps, slippageBps, maxLossBps, investPaused, harvestPaused);
    }

    // === Native ETH Convenience Methods ===

    /**
     * @dev Deposit native ETH, wrap to WETH, and mint shares to receiver.
     *      Requires `wrappedNative` to be set and equal to vault asset.
     * @param receiver Address receiving shares
     * @param minShares Minimum acceptable shares to protect from rounding
     */
    function depositETH(address receiver, uint256 minShares)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (wrappedNative == address(0) || wrappedNative != address(asset())) {
            revert Errors.InvalidConfiguration();
        }
        if (receiver == address(0)) revert Errors.InvalidReceiver();
        if (msg.value == 0) revert Errors.InvalidAmount();

        // Calculate shares before wrapping to avoid double-counting
        shares = previewDeposit(msg.value);
        if (shares < minShares) revert Errors.SlippageExceeded(minShares, shares);

        // Wrap ETH to WETH into this contract
        IWETH(wrappedNative).deposit{value: msg.value}();

        // Mint shares directly since WETH is already in vault
        _mint(receiver, shares);

        // Call deposit hook for user share tracking and investment
        _afterDeposit(msg.sender, receiver, msg.value, shares);

        emit Deposit(msg.sender, receiver, msg.value, shares);

        return shares;
    }

    /**
     * @dev Redeem shares for native ETH. Burns shares and unwraps WETH to ETH.
     * @param shares Amount of shares to redeem
     * @param receiver ETH recipient
     * @param owner Shares owner
     * @param minAssets Minimum acceptable assets to receive
     */
    function redeemETH(uint256 shares, address receiver, address owner, uint256 minAssets)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        if (wrappedNative == address(0) || wrappedNative != address(asset())) {
            revert Errors.InvalidConfiguration();
        }
        if (receiver == address(0)) revert Errors.InvalidReceiver();
        if (shares == 0) revert Errors.InvalidAmount();

        assets = previewRedeem(shares);
        if (assets < minAssets) revert Errors.SlippageExceeded(minAssets, assets);

        // Withdraw WETH to this contract using our overridden function
        _withdraw(msg.sender, address(this), owner, assets, shares);

        // Unwrap and send ETH
        IWETH(wrappedNative).withdraw(assets);
        (bool ok, ) = payable(receiver).call{value: assets}("");
        if (!ok) revert Errors.TransferFailed();

        return assets;
    }

    /**
     * @dev Withdraw specified asset amount as native ETH. Burns corresponding shares.
     * @param assets Asset amount to withdraw
     * @param receiver ETH recipient
     * @param owner Shares owner
     * @param maxShares Max shares to burn to protect from rounding up
     */
    function withdrawETH(uint256 assets, address receiver, address owner, uint256 maxShares)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        if (wrappedNative == address(0) || wrappedNative != address(asset())) {
            revert Errors.InvalidConfiguration();
        }
        if (receiver == address(0)) revert Errors.InvalidReceiver();
        if (assets == 0) revert Errors.InvalidAmount();

        shares = previewWithdraw(assets);
        if (shares > maxShares) revert Errors.SlippageExceeded(shares, maxShares);

        // Withdraw WETH to this contract using our overridden function
        _withdraw(msg.sender, address(this), owner, assets, shares);

        // Unwrap and send ETH
        IWETH(wrappedNative).withdraw(assets);
        (bool ok, ) = payable(receiver).call{value: assets}("");
        if (!ok) revert Errors.TransferFailed();

        return shares;
    }
}
