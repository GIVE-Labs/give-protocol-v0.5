// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {RoleManager} from "../src/access/RoleManager.sol";

contract BootstrapGrantRoles is Script {
    function run(address roleManagerAddr, address admin) public {
        vm.startBroadcast();

        RoleManager rm = RoleManager(roleManagerAddr);

        // Example grants - adjust role constants to match your RoleManager
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = rm.ROLE_CAMPAIGN_ADMIN();
        roles[1] = rm.ROLE_VAULT_OPS();
        roles[2] = rm.ROLE_TREASURY();
        rm.grantRoles(admin, roles);

        vm.stopBroadcast();
    }
}
