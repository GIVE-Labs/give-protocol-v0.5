// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import "../storage/StorageLib.sol";
import "../types/GiveTypes.sol";
import "../utils/GiveErrors.sol";
import "../utils/ACLShim.sol";

contract NGORegistry is Initializable, UUPSUpgradeable, ACLShim, Pausable {
    bytes32 public constant NGO_MANAGER_ROLE = keccak256("NGO_MANAGER_ROLE");
    bytes32 public constant DONATION_RECORDER_ROLE = keccak256("DONATION_RECORDER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    uint256 public constant TIMELOCK_DELAY = 24 hours;

    event NGOApproved(address indexed ngo, string metadataCid, bytes32 kycHash, address attestor, uint256 timestamp);
    event NGORemoved(address indexed ngo, string metadataCid, uint256 timestamp);
    event NGOUpdated(address indexed ngo, string oldMetadataCid, string newMetadataCid, uint256 newVersion);
    event CurrentNGOSet(address indexed oldNGO, address indexed newNGO, uint256 eta);
    event DonationRecorded(address indexed ngo, uint256 amount, uint256 newTotalReceived);

    function initialize(address acl) external initializer {
        if (acl == address(0)) revert GiveErrors.ZeroAddress();
        _setACLManager(acl);
    }

    // ===== View helpers =====

    function currentNGO() public view returns (address) {
        return _state().currentNGO;
    }

    function pendingCurrentNGO() public view returns (address) {
        return _state().pendingCurrentNGO;
    }

    function currentNGOChangeETA() public view returns (uint256) {
        return _state().currentNGOChangeETA;
    }

    function approvedNGOs() external view returns (address[] memory) {
        GiveTypes.NGORegistryState storage s = _state();
        address[] memory copy = new address[](s.approvedNGOs.length);
        for (uint256 i = 0; i < s.approvedNGOs.length; i++) {
            copy[i] = s.approvedNGOs[i];
        }
        return copy;
    }

    function isApproved(address ngo) public view returns (bool) {
        return _state().isApproved[ngo];
    }

    function ngoInfo(address ngo)
        external
        view
        returns (
            string memory metadataCid,
            bytes32 kycHash,
            address attestor,
            uint256 createdAt,
            uint256 updatedAt,
            uint256 version,
            uint256 totalReceived,
            bool isActive
        )
    {
        GiveTypes.NGOInfo storage info = _state().ngoInfo[ngo];
        return (
            info.metadataCid,
            info.kycHash,
            info.attestor,
            info.createdAt,
            info.updatedAt,
            info.version,
            info.totalReceived,
            info.isActive
        );
    }

    // ===== Management =====

    function addNGO(address ngo, string calldata metadataCid, bytes32 kycHash, address attestor)
        external
        onlyRole(NGO_MANAGER_ROLE)
        whenNotPaused
    {
        if (ngo == address(0)) revert GiveErrors.InvalidNGOAddress();
        if (_state().isApproved[ngo]) revert GiveErrors.NGOAlreadyApproved();
        if (bytes(metadataCid).length == 0) revert GiveErrors.InvalidMetadataCid();
        if (attestor == address(0)) revert GiveErrors.InvalidAttestor();

        GiveTypes.NGORegistryState storage s = _state();
        s.isApproved[ngo] = true;

        GiveTypes.NGOInfo storage info = s.ngoInfo[ngo];
        info.metadataCid = metadataCid;
        info.kycHash = kycHash;
        info.attestor = attestor;
        info.createdAt = block.timestamp;
        info.updatedAt = block.timestamp;
        info.version = 1;
        info.totalReceived = 0;
        info.isActive = true;

        s.approvedNGOs.push(ngo);

        if (s.currentNGO == address(0)) {
            s.currentNGO = ngo;
            emit CurrentNGOSet(address(0), ngo, 0);
        }

        emit NGOApproved(ngo, metadataCid, kycHash, attestor, block.timestamp);
    }

    function removeNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE) {
        GiveTypes.NGORegistryState storage s = _state();
        if (!s.isApproved[ngo]) revert GiveErrors.NGONotApproved();

        string memory metadataCid = s.ngoInfo[ngo].metadataCid;
        s.isApproved[ngo] = false;
        s.ngoInfo[ngo].isActive = false;
        s.ngoInfo[ngo].updatedAt = block.timestamp;

        _removeApprovedNGO(s, ngo);

        if (s.currentNGO == ngo) {
            s.currentNGO = s.approvedNGOs.length > 0 ? s.approvedNGOs[0] : address(0);
            emit CurrentNGOSet(ngo, s.currentNGO, 0);
        }

        emit NGORemoved(ngo, metadataCid, block.timestamp);
    }

    function updateNGO(address ngo, string calldata newMetadataCid, bytes32 newKycHash)
        external
        onlyRole(NGO_MANAGER_ROLE)
    {
        GiveTypes.NGORegistryState storage s = _state();
        if (!s.isApproved[ngo]) revert GiveErrors.NGONotApproved();
        if (bytes(newMetadataCid).length == 0) revert GiveErrors.InvalidMetadataCid();

        GiveTypes.NGOInfo storage info = s.ngoInfo[ngo];
        string memory oldMetadataCid = info.metadataCid;
        info.metadataCid = newMetadataCid;
        if (newKycHash != bytes32(0)) {
            info.kycHash = newKycHash;
        }
        info.updatedAt = block.timestamp;
        info.version++;

        emit NGOUpdated(ngo, oldMetadataCid, newMetadataCid, info.version);
    }

    function proposeCurrentNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE) {
        GiveTypes.NGORegistryState storage s = _state();
        if (ngo != address(0) && !s.isApproved[ngo]) revert GiveErrors.NGONotApproved();

        s.pendingCurrentNGO = ngo;
        s.currentNGOChangeETA = block.timestamp + TIMELOCK_DELAY;

        emit CurrentNGOSet(s.currentNGO, ngo, s.currentNGOChangeETA);
    }

    function executeCurrentNGOChange() external {
        GiveTypes.NGORegistryState storage s = _state();
        if (s.currentNGOChangeETA == 0) revert GiveErrors.NoTimelockPending();
        if (block.timestamp < s.currentNGOChangeETA) revert GiveErrors.TimelockNotReady();

        address oldNGO = s.currentNGO;
        s.currentNGO = s.pendingCurrentNGO;
        s.pendingCurrentNGO = address(0);
        s.currentNGOChangeETA = 0;

        emit CurrentNGOSet(oldNGO, s.currentNGO, 0);
    }

    function emergencySetCurrentNGO(address ngo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        GiveTypes.NGORegistryState storage s = _state();
        if (ngo != address(0) && !s.isApproved[ngo]) revert GiveErrors.NGONotApproved();

        address oldNGO = s.currentNGO;
        s.currentNGO = ngo;
        s.pendingCurrentNGO = address(0);
        s.currentNGOChangeETA = 0;

        emit CurrentNGOSet(oldNGO, ngo, 0);
    }

    function recordDonation(address ngo, uint256 amount) external onlyRole(DONATION_RECORDER_ROLE) {
        GiveTypes.NGORegistryState storage s = _state();
        if (!s.isApproved[ngo]) revert GiveErrors.NGONotApproved();

        GiveTypes.NGOInfo storage info = s.ngoInfo[ngo];
        info.totalReceived += amount;
        emit DonationRecorded(ngo, amount, info.totalReceived);
    }

    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    // ===== Internal helpers =====

    function _state() private view returns (GiveTypes.NGORegistryState storage) {
        return StorageLib.ngoRegistry();
    }

    function _removeApprovedNGO(GiveTypes.NGORegistryState storage s, address ngo) private {
        address[] storage list = s.approvedNGOs;
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == ngo) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }
    }

    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert GiveErrors.UnauthorizedCaller(msg.sender);
        }
    }
}
