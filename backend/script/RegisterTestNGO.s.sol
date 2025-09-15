// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";

/**
 * @title RegisterTestNGO
 * @dev Script to register a test NGO with proper IPFS metadata
 */
contract RegisterTestNGO is Script {
    function run() external {
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerKey);
        
        // NGORegistry address from local deployment
        address registryAddress = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
        NGORegistry registry = NGORegistry(registryAddress);
        
        vm.startBroadcast(deployerKey);
        
        // Register NGO with the real IPFS CID provided by user
        // Using full CID: bafkreievh2dfjrsy34mpxyd646yufvaadkfahcvpn6tk4dffoemaouwiy4
        string memory testMetadataCid = "bafkreievh2dfjrsy34mpxyd646yufvaadkfahcvpn6tk4dffoemaouwiy4";
        
        console.log("Registering NGO with address:", deployer);
        console.log("MetadataCid (full string):", testMetadataCid);
        
        // Create a mock KYC hash
        bytes32 kycHash = keccak256(abi.encodePacked("mock-kyc-hash-", deployer));
        
        // Register and approve the NGO in one call
        registry.addNGO(deployer, testMetadataCid, kycHash, deployer);
        
        console.log("NGO registered and approved successfully!");
        
        vm.stopBroadcast();
    }
}