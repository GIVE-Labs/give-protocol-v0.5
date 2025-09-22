// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../utils/Errors.sol";
import "../access/RoleAware.sol";

/**
 * @title NGORegistry
 * @dev Registry for managing approved NGOs in the GIVE Protocol
 * @notice Simplified registry for v0.1 - focuses on approval/removal of NGOs
 */
contract NGORegistry is RoleAware, Pausable {
    bytes32 public immutable NGO_MANAGER_ROLE;
    bytes32 public immutable DONATION_RECORDER_ROLE;
    bytes32 public immutable GUARDIAN_ROLE;

    // === State Variables ===
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => bool) public isApproved;
    mapping(address => NGOInfo) public ngoInfo;
    EnumerableSet.AddressSet private _approvedNGOs;

    // Legacy getter for backward compatibility
    address[] public approvedNGOs;
    address public currentNGO; // Single NGO for v0.1
    address public pendingCurrentNGO; // Pending NGO for timelock
    uint256 public currentNGOChangeETA; // ETA for currentNGO change
    uint256 public constant TIMELOCK_DELAY = 24 hours; // 24h timelock for governance changes

    struct NGOInfo {
        string metadataCid; // IPFS/Arweave hash for name/description
        bytes32 kycHash; // Hash of attestation docs or EAS UID
        address attestor; // Who verified the NGO
        uint256 createdAt; // Creation timestamp
        uint256 updatedAt; // Last update timestamp
        uint256 version; // Version for tracking changes
        uint256 totalReceived; // Total donations received
        bool isActive; // Whether NGO is active
    }

    // === Events ===
    event NGOApproved(address indexed ngo, string metadataCid, bytes32 kycHash, address attestor, uint256 timestamp);
    event NGORemoved(address indexed ngo, string metadataCid, uint256 timestamp);
    event NGOUpdated(address indexed ngo, string oldMetadataCid, string newMetadataCid, uint256 newVersion);
    event CurrentNGOSet(address indexed oldNGO, address indexed newNGO, uint256 eta);
    event DonationRecorded(address indexed ngo, uint256 amount, uint256 newTotalReceived);

    // === Constructor ===
    constructor(address roleManager_)
        RoleAware(roleManager_)
    {
        NGO_MANAGER_ROLE = roleManager.ROLE_CAMPAIGN_ADMIN();
        DONATION_RECORDER_ROLE = roleManager.ROLE_DONATION_RECORDER();
        GUARDIAN_ROLE = roleManager.ROLE_GUARDIAN();
    }

    // === NGO Management ===

    /**
     * @dev Approves an NGO for receiving donations
     * @param ngo The NGO address to approve
     * @param metadataCid IPFS/Arweave hash containing name/description
     * @param kycHash Hash of attestation documents or EAS UID
     * @param attestor Address of the entity that verified the NGO
     */
    function addNGO(address ngo, string calldata metadataCid, bytes32 kycHash, address attestor)
        external
        onlyRole(NGO_MANAGER_ROLE)
        whenNotPaused
    {
        if (ngo == address(0)) revert Errors.InvalidNGOAddress();
        if (isApproved[ngo]) revert Errors.NGOAlreadyApproved();
        if (bytes(metadataCid).length == 0) revert Errors.InvalidMetadataCid();
        if (attestor == address(0)) revert Errors.InvalidAttestor();

        uint256 timestamp = block.timestamp;
        isApproved[ngo] = true;
        ngoInfo[ngo] = NGOInfo({
            metadataCid: metadataCid,
            kycHash: kycHash,
            attestor: attestor,
            createdAt: timestamp,
            updatedAt: timestamp,
            version: 1,
            totalReceived: 0,
            isActive: true
        });

        _approvedNGOs.add(ngo);

        // Set as current NGO if none is set
        if (currentNGO == address(0)) {
            currentNGO = ngo;
            emit CurrentNGOSet(address(0), ngo, 0);
        }

        emit NGOApproved(ngo, metadataCid, kycHash, attestor, timestamp);
    }

    /**
     * @dev Removes an NGO from approved list
     * @param ngo The NGO address to remove
     */
    function removeNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE) {
        if (!isApproved[ngo]) revert Errors.NGONotApproved();

        string memory metadataCid = ngoInfo[ngo].metadataCid;

        isApproved[ngo] = false;
        ngoInfo[ngo].isActive = false;
        ngoInfo[ngo].updatedAt = block.timestamp;

        // Remove from set
        _approvedNGOs.remove(ngo);

        // Update current NGO if this was the current one
        if (currentNGO == ngo) {
            currentNGO = _approvedNGOs.length() > 0 ? _approvedNGOs.at(0) : address(0);
            emit CurrentNGOSet(ngo, currentNGO, 0);
        }

        emit NGORemoved(ngo, metadataCid, block.timestamp);
    }

    /**
     * @dev Updates NGO metadata
     * @param ngo The NGO address
     * @param newMetadataCid New IPFS/Arweave hash for metadata
     * @param newKycHash New KYC hash (optional, use existing if bytes32(0))
     */
    function updateNGO(address ngo, string calldata newMetadataCid, bytes32 newKycHash)
        external
        onlyRole(NGO_MANAGER_ROLE)
    {
        if (!isApproved[ngo]) revert Errors.NGONotApproved();
        if (bytes(newMetadataCid).length == 0) revert Errors.InvalidMetadataCid();

        string memory oldMetadataCid = ngoInfo[ngo].metadataCid;

        ngoInfo[ngo].metadataCid = newMetadataCid;
        if (newKycHash != bytes32(0)) {
            ngoInfo[ngo].kycHash = newKycHash;
        }
        ngoInfo[ngo].updatedAt = block.timestamp;
        ngoInfo[ngo].version++;

        emit NGOUpdated(ngo, oldMetadataCid, newMetadataCid, ngoInfo[ngo].version);
    }

    /**
     * @dev Proposes a new current NGO (starts timelock)
     * @param ngo The NGO address to set as current
     */
    function proposeCurrentNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE) {
        if (ngo != address(0) && !isApproved[ngo]) {
            revert Errors.NGONotApproved();
        }

        pendingCurrentNGO = ngo;
        currentNGOChangeETA = block.timestamp + TIMELOCK_DELAY;

        emit CurrentNGOSet(currentNGO, ngo, currentNGOChangeETA);
    }

    /**
     * @dev Executes the pending current NGO change after timelock
     */
    function executeCurrentNGOChange() external {
        if (block.timestamp < currentNGOChangeETA) revert Errors.TimelockNotReady();
        if (currentNGOChangeETA == 0) revert Errors.NoTimelockPending();

        address oldNGO = currentNGO;
        currentNGO = pendingCurrentNGO;

        // Reset timelock state
        pendingCurrentNGO = address(0);
        currentNGOChangeETA = 0;

        emit CurrentNGOSet(oldNGO, currentNGO, 0);
    }

    /**
     * @dev Emergency function to set current NGO immediately (admin only)
     * @param ngo The NGO address to set as current
     */
    function emergencySetCurrentNGO(address ngo) external onlyRole(GUARDIAN_ROLE) {
        if (ngo != address(0) && !isApproved[ngo]) {
            revert Errors.NGONotApproved();
        }

        address oldNGO = currentNGO;
        currentNGO = ngo;

        // Reset any pending changes
        pendingCurrentNGO = address(0);
        currentNGOChangeETA = 0;

        emit CurrentNGOSet(oldNGO, ngo, 0);
    }

    // === Donation Tracking ===

    /**
     * @dev Records a donation to an NGO (called by DonationRouter)
     * @param ngo The NGO that received the donation
     * @param amount The donation amount
     */
    function recordDonation(address ngo, uint256 amount) external onlyRole(DONATION_RECORDER_ROLE) whenNotPaused {
        if (!isApproved[ngo]) revert Errors.NGONotApproved();
        if (amount == 0) revert Errors.InvalidAmount();

        ngoInfo[ngo].totalReceived += amount;
        uint256 newTotal = ngoInfo[ngo].totalReceived;

        emit DonationRecorded(ngo, amount, newTotal);
    }

    // === View Functions ===

    /**
     * @dev Checks if an NGO is approved
     * @param ngo The NGO address to check
     * @return Whether the NGO is approved
     */
    function isNGOApproved(address ngo) external view returns (bool) {
        return isApproved[ngo];
    }

    /**
     * @dev Returns the current NGO for donations
     * @return The current NGO address
     */
    function getCurrentNGO() external view returns (address) {
        return currentNGO;
    }

    /**
     * @dev Returns all approved NGOs
     * @return Array of approved NGO addresses
     */
    function getApprovedNGOs() external view returns (address[] memory) {
        return _approvedNGOs.values();
    }

    /**
     * @dev Returns the total number of approved NGOs
     * @return Total count of approved NGOs
     */
    function getTotalApprovedNGOs() external view returns (uint256) {
        return _approvedNGOs.length();
    }

    /**
     * @dev Returns NGO information
     * @param ngo The NGO address
     * @return NGO information struct
     */
    function getNGOInfo(address ngo) external view returns (NGOInfo memory) {
        return ngoInfo[ngo];
    }

    /**
     * @dev Returns registry statistics
     * @return totalApproved Total number of approved NGOs
     * @return currentNGOAddress Current NGO address
     * @return totalDonations Total donations recorded
     */
    function getRegistryStats()
        external
        view
        returns (uint256 totalApproved, address currentNGOAddress, uint256 totalDonations)
    {
        uint256 totalDonated = 0;
        uint256 length = _approvedNGOs.length();

        for (uint256 i = 0; i < length; i++) {
            address ngo = _approvedNGOs.at(i);
            totalDonated += ngoInfo[ngo].totalReceived;
        }

        return (_approvedNGOs.length(), currentNGO, totalDonated);
    }

    // === Internal Functions ===
    // EnumerableSet handles add/remove operations internally

    // === Emergency Functions ===

    /**
     * @dev Emergency pause of the registry (admin only)
     */
    function emergencyPause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /**
     * @dev Guardian pause (can only pause, not unpause)
     */
    function guardianPause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the registry (admin only)
     */
    function unpause() external onlyRole(NGO_MANAGER_ROLE) {
        _unpause();
    }
}
