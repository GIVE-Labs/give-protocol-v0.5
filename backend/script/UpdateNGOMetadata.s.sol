// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {NGORegistry} from "../src/donation/NGORegistry.sol";

/**
 * @title UpdateNGOMetadata
 * @dev Script to update existing NGO with proper IPFS metadata
 */
contract UpdateNGOMetadata is Script {
    function run() external {
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerKey);
        
        // NGORegistry address from local deployment
        address registryAddress = 0xc5a5C42992dECbae36851359345FE25997F5C42d;
        NGORegistry registry = NGORegistry(registryAddress);
        
        vm.startBroadcast(deployerKey);
        
        // Update NGO with the real IPFS CID provided by user
        // Using full CID: bafkreievh2dfjrsy34mpxyd646yufvaadkfahcvpn6tk4dffoemaouwiy4
        string memory newMetadataCid = "bafkreievh2dfjrsy34mpxyd646yufvaadkfahcvpn6tk4dffoemaouwiy4";
        
        console.log("Updating NGO metadata for address:", deployer);
        console.log("New MetadataCid (full string):", newMetadataCid);
        
        // Update the NGO metadata (pass bytes32(0) to keep existing KYC hash)
        registry.updateNGO(deployer, newMetadataCid, bytes32(0));
        
        console.log("NGO metadata updated successfully!");
        
        vm.stopBroadcast();
    }
}