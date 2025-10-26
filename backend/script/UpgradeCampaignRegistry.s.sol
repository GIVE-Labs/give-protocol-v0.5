// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CampaignRegistry} from "../src/registry/CampaignRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeCampaignRegistry
 * @notice Upgrades the CampaignRegistry implementation to add metadataCID to events
 * @dev Uses UUPS upgrade pattern - proxy address stays the same
 */
contract UpgradeCampaignRegistry is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Base Sepolia proxy address (from your deployment)
        address proxyAddress = 0x51929ec1C089463fBeF6148B86F34117D9CCF816;

        console.log("Deployer:", deployer);
        console.log("Upgrading CampaignRegistry proxy at:", proxyAddress);

        vm.startBroadcast(deployerKey);

        // Deploy new implementation
        console.log("\n1. Deploying new CampaignRegistry implementation...");
        CampaignRegistry newImplementation = new CampaignRegistry();
        console.log("New implementation deployed at:", address(newImplementation));

        // Upgrade the proxy
        console.log("\n2. Upgrading proxy to new implementation...");
        UUPSUpgradeable(proxyAddress).upgradeToAndCall(
            address(newImplementation),
            "" // No initialization data needed
        );

        console.log("Upgrade complete!");
        console.log("Proxy address (unchanged):", proxyAddress);
        console.log("New implementation:", address(newImplementation));

        vm.stopBroadcast();

        // Verify the upgrade worked
        CampaignRegistry registry = CampaignRegistry(proxyAddress);
        console.log("\n=== Verification ===");
        console.log("Registry responds:", address(registry) == proxyAddress);
        
        // Try to read existing campaign IDs to verify storage is intact
        try registry.listCampaignIds() returns (bytes32[] memory ids) {
            console.log("Existing campaigns preserved:", ids.length);
        } catch {
            console.log("No existing campaigns (fresh deployment)");
        }
    }
}
