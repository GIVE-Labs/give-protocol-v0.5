// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

library SyntheticLogic {
    event SyntheticConfigured(bytes32 indexed id, address proxy, address asset);
    event SyntheticMinted(bytes32 indexed id, address indexed account, uint256 amount, uint256 newBalance);
    event SyntheticBurned(bytes32 indexed id, address indexed account, uint256 amount, uint256 newBalance);

    error SyntheticInactive(bytes32 id);
    error InsufficientSyntheticBalance(bytes32 id, address account, uint256 amount);

    function configure(bytes32 syntheticId, address proxy, address asset) internal {
        if (proxy == address(0) || asset == address(0)) revert();

        GiveTypes.SyntheticAsset storage syntheticAsset = StorageLib.syntheticState(syntheticId);
        syntheticAsset.id = syntheticId;
        syntheticAsset.proxy = proxy;
        syntheticAsset.asset = asset;
        syntheticAsset.active = true;

        emit SyntheticConfigured(syntheticId, proxy, asset);
    }

    function mint(bytes32 syntheticId, address account, uint256 amount) internal {
        if (amount == 0) return;
        GiveTypes.SyntheticAsset storage syntheticAsset = StorageLib.syntheticState(syntheticId);
        if (!syntheticAsset.active) revert SyntheticInactive(syntheticId);

        uint256 newBalance = syntheticAsset.balances[account] + amount;
        syntheticAsset.balances[account] = newBalance;
        syntheticAsset.totalSupply += amount;

        emit SyntheticMinted(syntheticId, account, amount, newBalance);
    }

    function burn(bytes32 syntheticId, address account, uint256 amount) internal {
        if (amount == 0) return;
        GiveTypes.SyntheticAsset storage syntheticAsset = StorageLib.syntheticState(syntheticId);
        if (!syntheticAsset.active) revert SyntheticInactive(syntheticId);

        uint256 balance = syntheticAsset.balances[account];
        if (balance < amount) revert InsufficientSyntheticBalance(syntheticId, account, amount);

        uint256 newBalance = balance - amount;
        syntheticAsset.balances[account] = newBalance;
        syntheticAsset.totalSupply -= amount;

        emit SyntheticBurned(syntheticId, account, amount, newBalance);
    }

    function balanceOf(bytes32 syntheticId, address account) internal view returns (uint256) {
        return StorageLib.syntheticState(syntheticId).balances[account];
    }

    function totalSupply(bytes32 syntheticId) internal view returns (uint256) {
        return StorageLib.syntheticState(syntheticId).totalSupply;
    }
}
