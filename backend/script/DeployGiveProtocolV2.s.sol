// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GiveProtocolCore} from "../src/core/GiveProtocolCore.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployGiveProtocolV2
 * @notice Deployment script for GIVE Protocol V2 with UUPS proxy
 * @dev Deploys GiveProtocolCore implementation and ERC1967 proxy
 */
contract DeployGiveProtocolV2 is Script {
    // Deployment parameters
    address public treasury;
    address public guardian;
    uint256 public protocolFeeBps;
    
    // Deployed contracts
    GiveProtocolCore public implementation;
    ERC1967Proxy public proxy;
    GiveProtocolCore public protocol;

    function run() external {
        // Load configuration from environment or use defaults
        treasury = vm.envOr("TREASURY", address(0x1111111111111111111111111111111111111111));
        guardian = vm.envOr("GUARDIAN", address(0x2222222222222222222222222222222222222222));
        protocolFeeBps = vm.envOr("PROTOCOL_FEE_BPS", uint256(1000)); // 10%
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== GIVE Protocol V2 Deployment ===");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Treasury:", treasury);
        console.log("Guardian:", guardian);
        console.log("Protocol Fee:", protocolFeeBps, "bps");
        console.log("");
        
        // 1. Deploy implementation
        console.log("1. Deploying GiveProtocolCore implementation...");
        implementation = new GiveProtocolCore();
        console.log("   Implementation deployed at:", address(implementation));
        
        // 2. Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            GiveProtocolCore.initialize.selector,
            treasury,
            guardian,
            protocolFeeBps
        );
        
        // 3. Deploy proxy
        console.log("2. Deploying ERC1967 Proxy...");
        proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("   Proxy deployed at:", address(proxy));
        
        // 4. Create protocol interface
        protocol = GiveProtocolCore(address(proxy));
        
        // 5. Verify deployment
        console.log("");
        console.log("=== Verification ===");
        console.log("Protocol Treasury:", protocol.getTreasury());
        console.log("Protocol Guardian:", protocol.getGuardian());
        console.log("Implementation Address:", protocol.getImplementation());
        console.log("Global Paused:", protocol.isGlobalPaused());
        
        vm.stopBroadcast();
        
        // Save deployment addresses
        _saveDeployment();
    }
    
    function _saveDeployment() internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "GIVE Protocol V2 Deployment\n",
            "============================\n",
            "Network: ", vm.toString(block.chainid), "\n",
            "Implementation: ", vm.toString(address(implementation)), "\n",
            "Proxy: ", vm.toString(address(proxy)), "\n",
            "Treasury: ", vm.toString(treasury), "\n",
            "Guardian: ", vm.toString(guardian), "\n",
            "Protocol Fee: ", vm.toString(protocolFeeBps), " bps\n"
        ));
        
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log(deploymentInfo);
    }
}
