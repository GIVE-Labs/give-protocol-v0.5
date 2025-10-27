// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../base/AdapterBase.sol";
import "../../utils/GiveErrors.sol";

contract CompoundingAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    uint256 public investedAmount;
    uint256 public pendingProfit;

    constructor(bytes32 adapterId, address asset, address vault) AdapterBase(adapterId, asset, vault) {}

    function totalAssets() external view override returns (uint256) {
        return asset().balanceOf(address(this));
    }

    function invest(uint256 assets) external override onlyVault {
        if (assets == 0) revert GiveErrors.InvalidInvestAmount();
        investedAmount += assets;
        emit Invested(assets);
    }

    function divest(uint256 assets) external override onlyVault returns (uint256 returned) {
        if (assets == 0) revert GiveErrors.InvalidDivestAmount();

        uint256 balance = asset().balanceOf(address(this));
        returned = assets > balance ? balance : assets;
        if (returned > 0) {
            asset().safeTransfer(vault(), returned);
        }

        if (returned <= investedAmount) {
            investedAmount -= returned;
        } else {
            investedAmount = 0;
        }

        emit Divested(assets, returned);
    }

    function harvest() external override onlyVault returns (uint256 profit, uint256) {
        uint256 balance = asset().balanceOf(address(this));
        if (balance > investedAmount) {
            profit = balance - investedAmount;
            asset().safeTransfer(vault(), profit);
        }
        emit Harvested(profit, 0);
        return (profit, 0);
    }

    function emergencyWithdraw() external override onlyVault returns (uint256 returned) {
        uint256 balance = asset().balanceOf(address(this));
        if (balance > 0) {
            asset().safeTransfer(vault(), balance);
        }
        investedAmount = 0;
        emit EmergencyWithdraw(balance);
        return balance;
    }

    // ----- Test helpers -----
    function addProfit(uint256 amount) external {
        pendingProfit += amount;
        asset().safeTransferFrom(msg.sender, address(this), amount);
    }
}
