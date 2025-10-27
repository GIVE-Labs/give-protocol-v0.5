// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../base/AdapterBase.sol";
import "../../utils/GiveErrors.sol";

contract GrowthAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    uint256 public totalDeposits;
    uint256 public growthIndex = 1e18;

    constructor(bytes32 adapterId, address asset, address vault) AdapterBase(adapterId, asset, vault) {}

    function totalAssets() external view override returns (uint256) {
        return (totalDeposits * growthIndex) / 1e18;
    }

    function invest(uint256 assets) external override onlyVault {
        if (assets == 0) revert GiveErrors.InvalidInvestAmount();
        totalDeposits += assets;
        emit Invested(assets);
    }

    function divest(uint256 assets) external override onlyVault returns (uint256 returned) {
        uint256 normalized = (assets * 1e18) / growthIndex;
        if (normalized > totalDeposits) {
            normalized = totalDeposits;
        }
        totalDeposits -= normalized;
        returned = (normalized * growthIndex) / 1e18;
        if (returned > 0) {
            asset().safeTransfer(vault(), returned);
        }
        emit Divested(assets, returned);
    }

    function harvest() external view override onlyVault returns (uint256, uint256) {
        return (0, 0);
    }

    function emergencyWithdraw() external override onlyVault returns (uint256 returned) {
        returned = (totalDeposits * growthIndex) / 1e18;
        totalDeposits = 0;
        growthIndex = 1e18;
        emit EmergencyWithdraw(returned);
    }

    // ----- Test helpers -----
    function setGrowthIndex(uint256 newIndex) external {
        require(newIndex >= 1e18, "growth < 1");
        growthIndex = newIndex;
    }
}
