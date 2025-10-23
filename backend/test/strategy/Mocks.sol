// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/interfaces/IYieldAdapter.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockAdapter is IYieldAdapter {
    IERC20 public override asset;
    address public override vault;
    uint256 public invested;

    constructor(IERC20 asset_, address vault_) {
        asset = asset_;
        vault = vault_;
    }

    function totalAssets() external view override returns (uint256) {
        return invested;
    }

    function invest(uint256 assets) external override {
        invested += assets;
    }

    function divest(uint256 assets) external override returns (uint256) {
        if (assets > invested) assets = invested;
        invested -= assets;
        return assets;
    }

    function harvest() external override returns (uint256, uint256) {
        return (0, 0);
    }

    function emergencyWithdraw() external override returns (uint256) {
        uint256 bal = invested;
        invested = 0;
        return bal;
    }
}
