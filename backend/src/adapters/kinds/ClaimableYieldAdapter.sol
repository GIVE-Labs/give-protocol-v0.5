// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../base/AdapterBase.sol";
import "../../utils/GiveErrors.sol";

contract ClaimableYieldAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    uint256 public investedAmount;
    uint256 public queuedYield;

    constructor(bytes32 adapterId, address asset, address vault) AdapterBase(adapterId, asset, vault) {}

    function totalAssets() external view override returns (uint256) {
        return investedAmount;
    }

    function invest(uint256 assets) external override onlyVault {
        if (assets == 0) revert GiveErrors.InvalidInvestAmount();
        investedAmount += assets;
        emit Invested(assets);
    }

    function divest(uint256 assets) external override onlyVault returns (uint256 returned) {
        if (assets == 0) revert GiveErrors.InvalidDivestAmount();
        if (assets > investedAmount) {
            returned = investedAmount;
            investedAmount = 0;
        } else {
            investedAmount -= assets;
            returned = assets;
        }
        if (returned > 0) {
            asset().safeTransfer(vault(), returned);
        }
        emit Divested(assets, returned);
    }

    function harvest() external override onlyVault returns (uint256 profit, uint256 loss) {
        profit = queuedYield;
        queuedYield = 0;
        if (profit > 0) {
            asset().safeTransfer(vault(), profit);
        }
        loss = 0;
        emit Harvested(profit, loss);
        return (profit, loss);
    }

    function emergencyWithdraw() external override onlyVault returns (uint256 returned) {
        returned = investedAmount + queuedYield;
        investedAmount = 0;
        queuedYield = 0;
        if (returned > 0) {
            asset().safeTransfer(vault(), returned);
        }
        emit EmergencyWithdraw(returned);
    }

    // ----- Test helpers -----
    function queueYield(uint256 amount) external {
        asset().safeTransferFrom(msg.sender, address(this), amount);
        queuedYield += amount;
    }
}
