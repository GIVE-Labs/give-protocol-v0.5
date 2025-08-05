// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NGORegistry.sol";
import "../src/MockYieldVault.sol";
import "../src/MorphImpactStaking.sol";
import "../src/YieldDistributor.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy NGO Registry
        NGORegistry ngoRegistry = new NGORegistry();
        console.log("NGORegistry deployed at:", address(ngoRegistry));
        
        // Deploy Mock Yield Vault
        MockYieldVault vault = new MockYieldVault();
        console.log("MockYieldVault deployed at:", address(vault));
        
        // Deploy Main Staking Contract
        MorphImpactStaking staking = new MorphImpactStaking(
            address(ngoRegistry), 
            address(vault)
        );
        console.log("MorphImpactStaking deployed at:", address(staking));
        
        // Deploy Yield Distributor
        YieldDistributor distributor = new YieldDistributor(
            address(ngoRegistry),
            address(staking)
        );
        console.log("YieldDistributor deployed at:", address(distributor));
        
        // Grant roles
        ngoRegistry.grantRole(ngoRegistry.VERIFIER_ROLE(), deployer);
        
        vm.stopBroadcast();
    }
}