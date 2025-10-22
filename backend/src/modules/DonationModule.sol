// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";

library DonationModule {
    bytes32 public constant MANAGER_ROLE = keccak256("DONATION_MODULE_MANAGER_ROLE");

    struct DonationConfigInput {
        bytes32 id;
        address routerProxy;
        address registryProxy;
        address feeRecipient;
        uint256 feeBps;
    }

    event DonationConfigured(bytes32 indexed id, address router, address registry, uint256 feeBps);

    function configure(bytes32 donationId, DonationConfigInput memory cfg) internal {
        bytes32 baseKey = keccak256(abi.encodePacked("donation", cfg.id));
        StorageLib.setAddress(keccak256(abi.encodePacked(baseKey, "router")), cfg.routerProxy);
        StorageLib.setAddress(keccak256(abi.encodePacked(baseKey, "registry")), cfg.registryProxy);
        StorageLib.setAddress(keccak256(abi.encodePacked(baseKey, "feeRecipient")), cfg.feeRecipient);
        StorageLib.setUint(keccak256(abi.encodePacked(baseKey, "feeBps")), cfg.feeBps);

        emit DonationConfigured(donationId, cfg.routerProxy, cfg.registryProxy, cfg.feeBps);
    }
}
