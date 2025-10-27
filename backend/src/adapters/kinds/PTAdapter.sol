// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../base/AdapterBase.sol";
import "../../utils/GiveErrors.sol";

contract PTAdapter is AdapterBase {
    using SafeERC20 for IERC20;

    struct Series {
        uint64 start;
        uint64 maturity;
    }

    Series public currentSeries;
    uint256 public deposits;

    constructor(bytes32 adapterId, address asset, address vault, uint64 start, uint64 maturity)
        AdapterBase(adapterId, asset, vault)
    {
        currentSeries = Series(start, maturity);
    }

    function totalAssets() external view override returns (uint256) {
        return deposits;
    }

    function invest(uint256 assets) external override onlyVault {
        if (assets == 0) revert GiveErrors.InvalidInvestAmount();
        deposits += assets;
        emit Invested(assets);
    }

    function divest(uint256 assets) external override onlyVault returns (uint256 returned) {
        if (assets == 0) revert GiveErrors.InvalidDivestAmount();
        if (assets > deposits) assets = deposits;
        deposits -= assets;
        returned = assets;
        asset().safeTransfer(vault(), assets);
        emit Divested(assets, returned);
    }

    function harvest() external view override onlyVault returns (uint256, uint256) {
        return (0, 0);
    }

    function emergencyWithdraw() external override onlyVault returns (uint256 returned) {
        returned = deposits;
        deposits = 0;
        emit EmergencyWithdraw(returned);
    }

    function rollover(uint64 newStart, uint64 newMaturity) external onlyVault {
        currentSeries = Series(newStart, newMaturity);
    }
}
