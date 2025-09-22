// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IYieldAdapter.sol";
import "../access/RoleAware.sol";
import "../utils/Errors.sol";

/**
 * @title MockYieldAdapter
 * @dev Mock yield adapter for testing purposes
 * @notice Simulates yield generation for local testing
 */
contract MockYieldAdapter is IYieldAdapter, RoleAware {
    using SafeERC20 for IERC20;

    bytes32 public immutable STRATEGY_ADMIN_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;
    bytes32 public immutable VAULT_OPS_ROLE;

    IERC20 private immutable _asset;
    address private immutable _vault;
    uint256 private _totalAssets;
    uint256 private _yieldRate; // Basis points per harvest (e.g., 100 = 1%)
    uint256 private _lastHarvestTime;
    bool private _simulateLoss;
    uint256 private _lossRate; // Basis points for simulated loss

    /**
     * @dev Constructor
     * @param roleManager_ Address of the shared role manager
     * @param asset_ The underlying asset token
     * @param vault_ The vault address
     */
    constructor(address roleManager_, address asset_, address vault_)
        RoleAware(roleManager_)
    {
        _asset = IERC20(asset_);
        _vault = vault_;
        _yieldRate = 250; // Default 2.5% yield per harvest
        _lastHarvestTime = block.timestamp;
        _simulateLoss = false;
        _lossRate = 0;

        STRATEGY_ADMIN_ROLE = roleManager.ROLE_STRATEGY_ADMIN();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
        VAULT_OPS_ROLE = roleManager.ROLE_VAULT_OPS();
    }

    modifier onlyVault() {
        if (msg.sender != _vault) {
            revert Errors.OnlyVault();
        }
        _;
    }

    /**
     * @dev Returns the underlying asset
     */
    function asset() external view override returns (IERC20) {
        return _asset;
    }

    /**
     * @dev Returns total assets under management
     */
    function totalAssets() external view override returns (uint256) {
        return _totalAssets;
    }

    /**
     * @dev Returns the vault address
     */
    function vault() external view override returns (address) {
        return _vault;
    }

    /**
     * @dev Invests assets (transfers from vault to adapter)
     * @param assets Amount to invest
     */
    function invest(uint256 assets) external override onlyVault {
        require(assets > 0, "MockYieldAdapter: Cannot invest zero assets");

        _asset.safeTransferFrom(_vault, address(this), assets);
        _totalAssets += assets;

        emit Invested(assets);
    }

    /**
     * @dev Divests assets (transfers from adapter back to vault)
     * @param assets Amount to divest
     * @return returned Actual amount returned
     */
    function divest(uint256 assets) external override onlyVault returns (uint256 returned) {
        require(assets > 0, "MockYieldAdapter: Cannot divest zero assets");
        require(assets <= _totalAssets, "MockYieldAdapter: Insufficient assets");

        returned = assets;
        _totalAssets -= assets;

        _asset.safeTransfer(_vault, returned);

        emit Divested(assets, returned);
    }

    /**
     * @dev Harvests yield and realizes profit/loss
     * @return profit Amount of profit realized
     * @return loss Amount of loss realized
     */
    function harvest() external override onlyVault returns (uint256 profit, uint256 loss) {
        if (_totalAssets == 0) {
            return (0, 0);
        }

        if (_simulateLoss) {
            // Simulate loss
            loss = (_totalAssets * _lossRate) / 10000;
            if (loss > _totalAssets) {
                loss = _totalAssets;
            }
            _totalAssets -= loss;
            profit = 0;
        } else {
            // Simulate profit
            profit = (_totalAssets * _yieldRate) / 10000;
            _totalAssets += profit;
            loss = 0;

            // Mint profit tokens to simulate yield
            if (profit > 0) {
                // In a real adapter, this would come from the protocol
                // For mock, we assume the asset can be minted or we have reserves
                // Here we just increase totalAssets - in practice you'd need actual tokens
            }
        }

        _lastHarvestTime = block.timestamp;
        emit Harvested(profit, loss);
    }

    /**
     * @dev Emergency withdrawal of all assets
     * @return returned Amount of assets returned
     */
    function emergencyWithdraw() external override returns (uint256 returned) {
        if (
            msg.sender != _vault &&
            !roleManager.hasRole(GUARDIAN_ROLE, msg.sender) &&
            !roleManager.hasRole(VAULT_OPS_ROLE, msg.sender)
        ) {
            revert Errors.UnauthorizedCaller(msg.sender);
        }
        returned = _totalAssets;
        _totalAssets = 0;

        if (returned > 0) {
            _asset.safeTransfer(_vault, returned);
        }

        emit EmergencyWithdraw(returned);
    }

    // Admin functions for testing

    /**
     * @dev Set yield rate for testing
     * @param yieldRate_ Yield rate in basis points
     */
    function setYieldRate(uint256 yieldRate_) external onlyRole(STRATEGY_ADMIN_ROLE) {
        require(yieldRate_ <= 10000, "MockYieldAdapter: Yield rate too high");
        _yieldRate = yieldRate_;
    }

    /**
     * @dev Toggle loss simulation
     * @param simulateLoss_ Whether to simulate loss
     * @param lossRate_ Loss rate in basis points
     */
    function setLossSimulation(bool simulateLoss_, uint256 lossRate_) external onlyRole(STRATEGY_ADMIN_ROLE) {
        require(lossRate_ <= 10000, "MockYieldAdapter: Loss rate too high");
        _simulateLoss = simulateLoss_;
        _lossRate = lossRate_;
    }

    /**
     * @dev Add yield tokens for testing (simulates external yield)
     * @param amount Amount of yield to add
     */
    function addYield(uint256 amount) external onlyRole(STRATEGY_ADMIN_ROLE) {
        if (amount > 0) {
            _asset.safeTransferFrom(msg.sender, address(this), amount);
            // Don't add to _totalAssets - this represents external yield
        }
    }

    /**
     * @dev Get current yield rate
     */
    function getYieldRate() external view returns (uint256) {
        return _yieldRate;
    }

    /**
     * @dev Get loss simulation settings
     */
    function getLossSimulation() external view returns (bool simulateLoss_, uint256 lossRate_) {
        return (_simulateLoss, _lossRate);
    }
}
