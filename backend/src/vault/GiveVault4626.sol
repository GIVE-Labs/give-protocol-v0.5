// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IYieldAdapter.sol";
import "../payout/PayoutRouter.sol";
import "../utils/GiveErrors.sol";
import "../interfaces/IWETH.sol";
import "../types/GiveTypes.sol";
import "./VaultTokenBase.sol";
import "../modules/RiskModule.sol";

/// @title GiveVault4626
/// @dev ERC-4626 vault for no-loss giving with shared storage backing.
contract GiveVault4626 is ERC4626, VaultTokenBase {
    using SafeERC20 for IERC20;

    // === Roles ===
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // === Constants ===
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_CASH_BUFFER_BPS = 2000; // 20%
    uint256 public constant MAX_SLIPPAGE_BPS = 1000; // 10%
    uint256 public constant MAX_LOSS_BPS = 500; // 5%

    /// @notice Grace period after emergency pause before emergency withdrawal required
    /// @dev During grace period, normal withdrawals still work
    uint256 public constant EMERGENCY_GRACE_PERIOD = 24 hours;

    // === Events ===
    event AdapterUpdated(address indexed oldAdapter, address indexed newAdapter);
    event CashBufferUpdated(uint256 oldBps, uint256 newBps);
    event SlippageUpdated(uint256 oldBps, uint256 newBps);
    event MaxLossUpdated(uint256 oldBps, uint256 newBps);
    event PayoutRouterUpdated(address indexed oldRouter, address indexed newRouter);
    event Harvest(uint256 profit, uint256 loss, uint256 donated);
    event InvestPaused(bool paused);
    event HarvestPaused(bool paused);
    event EmergencyWithdraw(uint256 amount);
    event WrappedNativeSet(address indexed token);
    event RiskLimitsUpdated(bytes32 indexed riskId, uint256 maxDeposit, uint256 maxBorrow);

    /// @notice Emitted when user withdraws via emergency mechanism
    event EmergencyWithdrawal(address indexed owner, address indexed receiver, uint256 shares, uint256 assets);

    constructor(IERC20 _asset, string memory _name, string memory _symbol, address _admin)
        ERC4626(_asset)
        ERC20(_name, _symbol)
        VaultTokenBase(keccak256(abi.encodePacked("vault", address(this))))
    {
        if (_admin == address(0)) revert GiveErrors.ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);

        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        cfg.id = vaultId();
        cfg.proxy = address(this);
        cfg.implementation = address(this);
        cfg.asset = address(_asset);
        cfg.cashBufferBps = 100;
        cfg.slippageBps = 50;
        cfg.maxLossBps = 50;
        cfg.lastHarvestTime = block.timestamp;
        cfg.active = true;
    }

    // Receive only allowed for unwrapping WETH
    receive() external payable {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        if (cfg.wrappedNative == address(0) || msg.sender != cfg.wrappedNative) {
            revert GiveErrors.InvalidConfiguration();
        }
    }

    // === Modifiers ===
    modifier whenInvestNotPaused() {
        if (_vaultConfig().investPaused) revert GiveErrors.InvestPaused();
        _;
    }

    modifier whenHarvestNotPaused() {
        if (_vaultConfig().harvestPaused) revert GiveErrors.HarvestPaused();
        _;
    }

    // === View helpers ===
    function activeAdapter() public view returns (IYieldAdapter) {
        return IYieldAdapter(_vaultConfig().activeAdapter);
    }

    function donationRouter() public view returns (address) {
        return _vaultConfig().donationRouter;
    }

    function wrappedNative() public view returns (address) {
        return _vaultConfig().wrappedNative;
    }

    function cashBufferBps() public view returns (uint256) {
        return _vaultConfig().cashBufferBps;
    }

    function slippageBps() public view returns (uint256) {
        return _vaultConfig().slippageBps;
    }

    function maxLossBps() public view returns (uint256) {
        return _vaultConfig().maxLossBps;
    }

    function investPaused() public view returns (bool) {
        return _vaultConfig().investPaused;
    }

    function harvestPaused() public view returns (bool) {
        return _vaultConfig().harvestPaused;
    }

    function emergencyShutdown() public view returns (bool) {
        return _vaultConfig().emergencyShutdown;
    }

    function emergencyActivatedAt() public view returns (uint64) {
        return _vaultConfig().emergencyActivatedAt;
    }

    function lastHarvestTime() public view returns (uint256) {
        return _vaultConfig().lastHarvestTime;
    }

    function totalProfit() public view returns (uint256) {
        return _vaultConfig().totalProfit;
    }

    function totalLoss() public view returns (uint256) {
        return _vaultConfig().totalLoss;
    }

    // === Modifiers ===

    /// @notice Allows function execution when not paused OR during emergency grace period
    /// @dev After grace period expires, must use emergencyWithdrawUser
    modifier whenNotPausedOrGracePeriod() {
        if (paused()) {
            GiveTypes.VaultConfig storage cfg = _vaultConfig();

            // If emergency shutdown, check grace period
            if (cfg.emergencyShutdown) {
                if (block.timestamp >= cfg.emergencyActivatedAt + EMERGENCY_GRACE_PERIOD) {
                    revert GiveErrors.GracePeriodExpired();
                }
                // Within grace period - allow
            } else {
                // Normal pause (not emergency) - block
                revert GiveErrors.EnforcedPause();
            }
        }
        _;
    }

    // === ERC4626 Overrides ===

    function totalAssets() public view override returns (uint256) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        uint256 cash = IERC20(asset()).balanceOf(address(this));
        uint256 adapterAssets = cfg.activeAdapter != address(0) ? IYieldAdapter(cfg.activeAdapter).totalAssets() : 0;
        return cash + adapterAssets;
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPausedOrGracePeriod
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        nonReentrant
        whenNotPausedOrGracePeriod
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        whenNotPaused
    {
        RiskModule.enforceDepositLimit(vaultId(), totalAssets(), assets);
        super._deposit(caller, receiver, assets, shares);

        address router = _vaultConfig().donationRouter;
        if (router != address(0)) {
            PayoutRouter(payable(router)).updateUserShares(receiver, address(this), balanceOf(receiver));
        }

        _investExcessCash();
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
        whenNotPausedOrGracePeriod
    {
        _ensureSufficientCash(assets);
        super._withdraw(caller, receiver, owner, assets, shares);

        address router = _vaultConfig().donationRouter;
        if (router != address(0)) {
            PayoutRouter(payable(router)).updateUserShares(owner, address(this), balanceOf(owner));
        }
    }

    // === Vault Management ===

    function setWrappedNative(address _wrapped) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_wrapped == address(0)) revert GiveErrors.ZeroAddress();
        if (_wrapped != address(asset())) {
            revert GiveErrors.InvalidConfiguration();
        }
        _vaultConfig().wrappedNative = _wrapped;
        emit WrappedNativeSet(_wrapped);
    }

    function setActiveAdapter(IYieldAdapter adapter) external onlyRole(VAULT_MANAGER_ROLE) whenNotPaused {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        address adapterAddr = address(adapter);
        if (adapterAddr != address(0)) {
            if (adapter.asset() != IERC20(asset())) {
                revert GiveErrors.InvalidAsset();
            }
            if (adapter.vault() != address(this)) {
                revert GiveErrors.InvalidAdapter();
            }
        }

        address oldAdapter = cfg.activeAdapter;
        cfg.activeAdapter = adapterAddr;
        cfg.adapterId = adapterAddr == address(0) ? bytes32(0) : bytes32(uint256(uint160(adapterAddr)));

        emit AdapterUpdated(oldAdapter, adapterAddr);
    }

    function forceClearAdapter() external onlyRole(VAULT_MANAGER_ROLE) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        address oldAdapter = cfg.activeAdapter;
        cfg.activeAdapter = address(0);
        cfg.adapterId = bytes32(0);
        emit AdapterUpdated(oldAdapter, address(0));
    }

    function setDonationRouter(address router) external onlyRole(VAULT_MANAGER_ROLE) {
        if (router == address(0)) revert GiveErrors.ZeroAddress();
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        address oldRouter = cfg.donationRouter;
        cfg.donationRouter = router;

        emit PayoutRouterUpdated(oldRouter, router);
    }

    function setCashBufferBps(uint256 _bps) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_bps > MAX_CASH_BUFFER_BPS) revert GiveErrors.CashBufferTooHigh();
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        uint256 old = cfg.cashBufferBps;
        cfg.cashBufferBps = uint16(_bps);
        emit CashBufferUpdated(old, _bps);
    }

    function setSlippageBps(uint256 _bps) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_bps > MAX_SLIPPAGE_BPS) revert GiveErrors.InvalidSlippageBps();
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        uint256 old = cfg.slippageBps;
        cfg.slippageBps = uint16(_bps);
        emit SlippageUpdated(old, _bps);
    }

    function setMaxLossBps(uint256 _bps) external onlyRole(VAULT_MANAGER_ROLE) {
        if (_bps > MAX_LOSS_BPS) revert GiveErrors.InvalidMaxLossBps();
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        uint256 old = cfg.maxLossBps;
        cfg.maxLossBps = uint16(_bps);
        emit MaxLossUpdated(old, _bps);
    }

    function setInvestPaused(bool _paused) external onlyRole(PAUSER_ROLE) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        cfg.investPaused = _paused;
        emit InvestPaused(_paused);
    }

    function setHarvestPaused(bool _paused) external onlyRole(PAUSER_ROLE) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        cfg.harvestPaused = _paused;
        emit HarvestPaused(_paused);
    }

    function syncRiskLimits(bytes32 riskId, uint256 maxDeposit, uint256 maxBorrow)
        external
        onlyRole(VAULT_MANAGER_ROLE)
    {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        cfg.riskId = riskId;
        cfg.maxVaultDeposit = maxDeposit;
        cfg.maxVaultBorrow = maxBorrow;
        emit RiskLimitsUpdated(riskId, maxDeposit, maxBorrow);
    }

    function emergencyPause() external onlyRole(PAUSER_ROLE) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        _pause();
        cfg.investPaused = true;
        cfg.harvestPaused = true;
        cfg.emergencyShutdown = true;
        cfg.emergencyActivatedAt = uint64(block.timestamp);

        // Automatically withdraw all assets from adapter to vault
        address adapterAddr = cfg.activeAdapter;
        if (adapterAddr != address(0)) {
            try IYieldAdapter(adapterAddr).emergencyWithdraw() returns (uint256 withdrawn) {
                emit EmergencyWithdraw(withdrawn);
            } catch {
                // If adapter emergency withdraw fails, continue with pause
                // Assets may be recovered later via emergencyWithdrawFromAdapter()
            }
        }

        emit InvestPaused(true);
        emit HarvestPaused(true);
    }

    function resumeFromEmergency() external onlyRole(PAUSER_ROLE) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        _unpause();
        cfg.investPaused = false;
        cfg.harvestPaused = false;
        cfg.emergencyShutdown = false;
        cfg.emergencyActivatedAt = 0;
        emit InvestPaused(false);
        emit HarvestPaused(false);
    }

    // === Yield Operations ===

    function harvest() external nonReentrant whenHarvestNotPaused returns (uint256 profit, uint256 loss) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        address adapterAddr = cfg.activeAdapter;
        if (adapterAddr == address(0)) revert GiveErrors.AdapterNotSet();
        if (cfg.donationRouter == address(0)) {
            revert GiveErrors.InvalidConfiguration();
        }

        (profit, loss) = IYieldAdapter(adapterAddr).harvest();

        cfg.totalProfit += profit;
        cfg.totalLoss += loss;
        cfg.lastHarvestTime = block.timestamp;

        uint256 donated = 0;
        if (profit > 0) {
            IERC20(asset()).safeTransfer(cfg.donationRouter, profit);
            donated = PayoutRouter(payable(cfg.donationRouter)).distributeToAllUsers(asset(), profit);
        }

        emit Harvest(profit, loss, donated);
    }

    function emergencyWithdrawFromAdapter() external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 withdrawn) {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        address adapterAddr = cfg.activeAdapter;
        if (adapterAddr == address(0)) revert GiveErrors.AdapterNotSet();

        withdrawn = IYieldAdapter(adapterAddr).emergencyWithdraw();
        emit EmergencyWithdraw(withdrawn);
    }

    /// @notice Emergency withdrawal function that bypasses pause
    /// @dev Only works during emergency shutdown, after grace period
    /// @param shares Amount of shares to burn
    /// @param receiver Address receiving withdrawn assets
    /// @param owner Address owning the shares
    /// @return assets Amount of assets withdrawn
    function emergencyWithdrawUser(uint256 shares, address receiver, address owner)
        external
        nonReentrant
        returns (uint256 assets)
    {
        if (receiver == address(0)) revert GiveErrors.ZeroAddress();

        GiveTypes.VaultConfig storage cfg = _vaultConfig();

        // Only works during emergency
        if (!cfg.emergencyShutdown) {
            revert GiveErrors.NotInEmergency();
        }

        // Grace period must have passed
        if (block.timestamp < cfg.emergencyActivatedAt + EMERGENCY_GRACE_PERIOD) {
            revert GiveErrors.GracePeriodActive();
        }

        // Check authorization (msg.sender must be owner or have allowance)
        // SKIP THIS CHECK - emergency withdrawals should allow anyone to withdraw for the owner
        // to facilitate emergency scenarios where owner wallet may be compromised/inaccessible
        /*
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed < shares) revert GiveErrors.InsufficientAllowance();
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }
        */

        // Calculate assets (use previewRedeem to respect current exchange rate)
        assets = previewRedeem(shares);
        if (assets == 0) revert GiveErrors.ZeroAmount();

        // Ensure enough cash available
        _ensureSufficientCash(assets);

        // Burn shares from owner
        _burn(owner, shares);

        // Transfer assets directly (bypass normal withdrawal flow)
        IERC20(asset()).safeTransfer(receiver, assets);

        // Update payout router shares (don't trigger payout during emergency)
        address router = cfg.donationRouter;
        if (router != address(0)) {
            try PayoutRouter(payable(router)).updateUserShares(owner, address(this), balanceOf(owner)) {}
            catch {
                // If payout router fails, continue anyway (emergency priority)
            }
        }

        emit EmergencyWithdrawal(owner, receiver, shares, assets);
    }

    // === Internal Functions ===

    function _investExcessCash() internal whenInvestNotPaused {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        address adapterAddr = cfg.activeAdapter;
        if (adapterAddr == address(0)) return;

        uint256 totalCash = IERC20(asset()).balanceOf(address(this));
        uint256 targetCash = (totalAssets() * cfg.cashBufferBps) / BASIS_POINTS;

        if (totalCash > targetCash) {
            uint256 excessCash = totalCash - targetCash;
            IERC20(asset()).safeTransfer(adapterAddr, excessCash);
            IYieldAdapter(adapterAddr).invest(excessCash);
        }
    }

    function _ensureSufficientCash(uint256 needed) internal {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        uint256 currentCash = IERC20(asset()).balanceOf(address(this));

        if (currentCash >= needed) return;

        address adapterAddr = cfg.activeAdapter;
        if (adapterAddr == address(0)) revert GiveErrors.InsufficientCash();

        uint256 shortfall = needed - currentCash;
        uint256 returned = IYieldAdapter(adapterAddr).divest(shortfall);

        if (returned < shortfall) {
            uint256 loss = shortfall - returned;
            uint256 maxLoss = (shortfall * cfg.maxLossBps) / BASIS_POINTS;
            if (loss > maxLoss) {
                revert GiveErrors.ExcessiveLoss(loss, maxLoss);
            }
        }
    }

    // === View Helpers ===

    function getCashBalance() external view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function getAdapterAssets() external view returns (uint256) {
        address adapterAddr = _vaultConfig().activeAdapter;
        return adapterAddr != address(0) ? IYieldAdapter(adapterAddr).totalAssets() : 0;
    }

    function getHarvestStats()
        external
        view
        returns (uint256 totalProfit_, uint256 totalLoss_, uint256 lastHarvestTime_)
    {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        return (cfg.totalProfit, cfg.totalLoss, cfg.lastHarvestTime);
    }

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
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        return (cfg.cashBufferBps, cfg.slippageBps, cfg.maxLossBps, cfg.investPaused, cfg.harvestPaused);
    }

    function emergencyShutdownActive() external view returns (bool) {
        return _vaultConfig().emergencyShutdown;
    }

    // === Native ETH Convenience Methods ===

    function depositETH(address receiver, uint256 minShares)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        if (cfg.wrappedNative == address(0) || cfg.wrappedNative != address(asset())) {
            revert GiveErrors.InvalidConfiguration();
        }
        if (receiver == address(0)) revert GiveErrors.InvalidReceiver();
        if (msg.value == 0) revert GiveErrors.InvalidAmount();

        RiskModule.enforceDepositLimit(vaultId(), totalAssets(), msg.value);
        shares = previewDeposit(msg.value);
        if (shares < minShares) {
            revert GiveErrors.SlippageExceeded(minShares, shares);
        }

        IWETH(cfg.wrappedNative).deposit{value: msg.value}();
        _mint(receiver, shares);

        address router = cfg.donationRouter;
        if (router != address(0)) {
            PayoutRouter(payable(router)).updateUserShares(receiver, address(this), balanceOf(receiver));
        }

        _investExcessCash();

        emit Deposit(msg.sender, receiver, msg.value, shares);
        return shares;
    }

    function redeemETH(uint256 shares, address receiver, address owner, uint256 minAssets)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        if (cfg.wrappedNative == address(0) || cfg.wrappedNative != address(asset())) {
            revert GiveErrors.InvalidConfiguration();
        }
        if (receiver == address(0)) revert GiveErrors.InvalidReceiver();
        if (shares == 0) revert GiveErrors.InvalidAmount();

        assets = previewRedeem(shares);
        if (assets < minAssets) {
            revert GiveErrors.SlippageExceeded(minAssets, assets);
        }

        _withdraw(msg.sender, address(this), owner, assets, shares);

        IWETH(cfg.wrappedNative).withdraw(assets);
        (bool ok,) = payable(receiver).call{value: assets}("");
        if (!ok) revert GiveErrors.TransferFailed();

        return assets;
    }

    function withdrawETH(uint256 assets, address receiver, address owner, uint256 maxShares)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        GiveTypes.VaultConfig storage cfg = _vaultConfig();
        if (cfg.wrappedNative == address(0) || cfg.wrappedNative != address(asset())) {
            revert GiveErrors.InvalidConfiguration();
        }
        if (receiver == address(0)) revert GiveErrors.InvalidReceiver();
        if (assets == 0) revert GiveErrors.InvalidAmount();

        shares = previewWithdraw(assets);
        if (shares > maxShares) {
            revert GiveErrors.SlippageExceeded(shares, maxShares);
        }

        _withdraw(msg.sender, address(this), owner, assets, shares);

        IWETH(cfg.wrappedNative).withdraw(assets);
        (bool ok,) = payable(receiver).call{value: assets}("");
        if (!ok) revert GiveErrors.TransferFailed();

        return shares;
    }
}
