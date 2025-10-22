// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";

library RiskModule {
    bytes32 public constant MANAGER_ROLE = keccak256("RISK_MODULE_MANAGER_ROLE");

    struct RiskConfigInput {
        bytes32 id;
        uint16 ltvBps;
        uint16 liquidationThresholdBps;
        uint16 liquidationPenaltyBps;
        uint16 borrowCapBps;
        uint16 depositCapBps;
        bytes32 dataHash;
    }

    event RiskConfigured(bytes32 indexed id, uint16 ltvBps, uint16 liquidationThresholdBps);

    function configure(bytes32 riskId, RiskConfigInput memory cfg) internal {
        GiveTypes.RiskConfig storage info = StorageLib.riskConfig(riskId);
        info.id = riskId;
        info.createdAt = uint64(block.timestamp);
        info.updatedAt = uint64(block.timestamp);
        info.ltvBps = cfg.ltvBps;
        info.liquidationThresholdBps = cfg.liquidationThresholdBps;
        info.liquidationPenaltyBps = cfg.liquidationPenaltyBps;
        info.borrowCapBps = cfg.borrowCapBps;
        info.depositCapBps = cfg.depositCapBps;
        info.dataHash = cfg.dataHash;

        emit RiskConfigured(riskId, cfg.ltvBps, cfg.liquidationThresholdBps);
    }
}
