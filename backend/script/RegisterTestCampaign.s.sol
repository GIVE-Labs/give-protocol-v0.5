// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CampaignRegistry} from "../src/registry/CampaignRegistry.sol";
import {GiveTypes} from "../src/types/GiveTypes.sol";

/**
 * @title RegisterTestCampaign
 * @dev Script to register a test campaign on Base Sepolia using v0.5 API
 */
contract RegisterTestCampaign is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // Base Sepolia campaign registry
        address registryAddress = 0x51929ec1C089463fBeF6148B86F34117D9CCF816;
        CampaignRegistry registry = CampaignRegistry(registryAddress);

        // Campaign details
        bytes32 campaignId = keccak256("TEST_CLIMATE_CAMPAIGN_V1");
        address recipientAddress = 0x742D35CC6634c0532925A3b844BC9E7595F0BEb0; // EIP-55 checksummed
        bytes32 strategyId = 0x79861c7f93db9d6c9c5c46da4760ee78aef494b26e84a8b82a4cdfbf4dbdc848; // Real deployed strategy
        bytes32 metadataHash = bytes32(uint256(keccak256("QmTest123456789"))); // Example IPFS hash

        console.log("Deployer address:", deployer);
        console.log("Campaign Registry:", registryAddress);
        console.logBytes32(campaignId);

        vm.startBroadcast(deployerKey);

        // Submit campaign with proper struct
        CampaignRegistry.CampaignInput memory input = CampaignRegistry.CampaignInput({
            id: campaignId,
            payoutRecipient: recipientAddress,
            strategyId: strategyId,
            metadataHash: metadataHash,
            metadataCID: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
            targetStake: 10 ether, // Target fundraising goal
            minStake: 0.01 ether, // Minimum stake per donor
            fundraisingStart: uint64(block.timestamp),
            fundraisingEnd: uint64(block.timestamp + 90 days)
        });

        console.log("Submitting campaign...");
        registry.submitCampaign(input);
        console.log("Campaign submitted");

        // Approve campaign (requires campaign admin role)
        // Second param is curator address
        console.log("Approving campaign...");
        registry.approveCampaign(campaignId, deployer);
        console.log("Campaign approved with curator:", deployer);

        vm.stopBroadcast();

        // Verify campaign was created
        GiveTypes.CampaignConfig memory cfg = registry.getCampaign(campaignId);
        console.log("\n=== Campaign Details ===");
        console.log("Status:", uint256(cfg.status)); // 1 = Approved
        console.log("Recipient:", cfg.payoutRecipient);
        console.log("Curator:", cfg.curator);
        console.log("Target stake:", cfg.targetStake);
    }
}
