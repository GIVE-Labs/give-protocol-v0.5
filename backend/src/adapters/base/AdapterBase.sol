// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../interfaces/IYieldAdapter.sol";
import "../../utils/Errors.sol";

abstract contract AdapterBase is IYieldAdapter {
    bytes32 public immutable adapterId;
    address public immutable adapterAsset;
    address public immutable adapterVault;

    constructor(bytes32 id, address asset_, address vault_) {
        adapterId = id;
        adapterAsset = asset_;
        adapterVault = vault_;
    }

    modifier onlyVault() {
        if (msg.sender != adapterVault) revert Errors.OnlyVault();
        _;
    }

    function asset() public view override returns (IERC20) {
        return IERC20(adapterAsset);
    }

    function vault() public view override returns (address) {
        return adapterVault;
    }
}
