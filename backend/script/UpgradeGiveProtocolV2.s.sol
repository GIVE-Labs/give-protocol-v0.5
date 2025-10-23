// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GiveProtocolCore} from "../src/core/GiveProtocolCore.sol";
import {DataTypes} from "../src/libraries/types/DataTypes.sol";

/**
 * @title UpgradeGiveProtocolV2
 * @notice Script to upgrade GiveProtocolCore implementation
 * @dev Uses UUPS upgradeability pattern
 */
contract UpgradeGiveProtocolV2 is Script {
    address public proxyAddress;
    GiveProtocolCore public oldProtocol;
    GiveProtocolCore public newImplementation;
    
    function run() external {
        // Load proxy address from environment
        proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== GIVE Protocol V2 Upgrade ===");
        console.log("Upgrader:", deployer);
        console.log("Proxy Address:", proxyAddress);
        console.log("");
        
        // Connect to existing protocol
        oldProtocol = GiveProtocolCore(proxyAddress);
        
        // Get current implementation
        address oldImplementation = oldProtocol.getImplementation();
        console.log("Old Implementation:", oldImplementation);
        
        // Deploy new implementation
        console.log("1. Deploying new implementation...");
        newImplementation = new GiveProtocolCore();
        console.log("   New Implementation:", address(newImplementation));
        
        // Upgrade proxy to new implementation
        console.log("2. Upgrading proxy...");
        oldProtocol.upgradeToAndCall(address(newImplementation), "");
        
        // Verify upgrade
        console.log("");
        console.log("=== Verification ===");
        address currentImplementation = oldProtocol.getImplementation();
        console.log("Current Implementation:", currentImplementation);
        console.log("Upgrade successful:", currentImplementation == address(newImplementation));
        
        // Check protocol state is preserved
        console.log("Treasury (preserved):", oldProtocol.getTreasury());
        console.log("Guardian (preserved):", oldProtocol.getGuardian());
        
        vm.stopBroadcast();
    }
}
