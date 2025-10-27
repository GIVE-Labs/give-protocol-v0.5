// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";

/**
 * @title RegisterSepoliaNGO
 * @dev Script to register an NGO on Sepolia testnet with proper IPFS metadata
 */
contract RegisterSepoliaNGO is Script {
    function run() external {
        // Use environment variable for admin address or fallback to deployerKey
        uint256 deployerKey = vm.envOr("DEPLOYER_KEY", uint256(0));
        address admin = vm.envOr("ADMIN_ADDRESS", deployerKey == 0 ? msg.sender : vm.addr(deployerKey));

        // NGORegistry address from Sepolia deployment
        address registryAddress = 0x77182f2C8E86233D3B0095446Da20ecDecF96Cc2;
        NGORegistry registry = NGORegistry(registryAddress);

        // NGO details
        address ngoAddress = 0x28c50Bcdb2288fCdcf84DF4198F06Df92Dad6DFc;
        string memory metadataCid = "bafkreid444vhsv55pwwyz6ls4raf5hjadckwjo4qwdvbfs5gdedd2pmjxm";

        // Handle deployment based on whether we're using private key or account
        if (deployerKey == 0) {
            // Account-based deployment
            vm.startBroadcast();
        } else {
            // Private key deployment
            vm.startBroadcast(deployerKey);
        }

        console.log("Admin address:", admin);
        console.log("NGO Registry address:", registryAddress);
        console.log("Registering NGO with address:", ngoAddress);
        console.log("MetadataCid:", metadataCid);

        // Create a KYC hash for the NGO
        bytes32 kycHash = keccak256(abi.encodePacked("kyc-hash-", ngoAddress));

        // Check if admin has the required role
        console.log("Admin has NGO_MANAGER_ROLE:", registry.hasRole(registry.NGO_MANAGER_ROLE(), admin));

        // Register and approve the NGO
        registry.addNGO(ngoAddress, metadataCid, kycHash, admin);

        console.log("NGO registered and approved successfully!");
        console.log("KYC Hash:", vm.toString(kycHash));

        // Verify the NGO was registered
        console.log("Verification - Is Approved:", registry.isApproved(ngoAddress));

        vm.stopBroadcast();
    }
}
