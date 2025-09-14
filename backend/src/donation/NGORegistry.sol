// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../utils/Errors.sol";

/**
 * @title NGORegistry
 * @dev Registry for managing approved NGOs in the GIVE Protocol
 * @notice Simplified registry for v0.1 - focuses on approval/removal of NGOs
 */
contract NGORegistry is AccessControl, ReentrancyGuard, Pausable {
    // === Roles ===
    bytes32 public constant NGO_MANAGER_ROLE = keccak256("NGO_MANAGER_ROLE");
    bytes32 public constant DONATION_RECORDER_ROLE = keccak256("DONATION_RECORDER_ROLE");

    // === State Variables ===
    mapping(address => bool) public isApproved;
    mapping(address => NGOInfo) public ngoInfo;
    address[] public approvedNGOs;

    uint256 public totalApprovedNGOs;
    address public currentNGO; // Single NGO for v0.1

    struct NGOInfo {
        string name;
        string description;
        uint256 approvalTime;
        uint256 totalReceived;
        bool isActive;
    }

    // === Events ===
    event NGOApproved(address indexed ngo, string name, uint256 timestamp);
    event NGORemoved(address indexed ngo, string name, uint256 timestamp);
    event NGOUpdated(address indexed ngo, string name, string description);
    event CurrentNGOSet(address indexed oldNGO, address indexed newNGO);
    event DonationRecorded(address indexed ngo, uint256 amount);

    // === Constructor ===
    constructor(address _admin) {
        if (_admin == address(0)) revert Errors.ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(NGO_MANAGER_ROLE, _admin);
    }

    // === NGO Management ===

    /**
     * @dev Approves an NGO for receiving donations
     * @param ngo The NGO address to approve
     * @param name The NGO name
     * @param description The NGO description
     */
    function addNGO(address ngo, string calldata name, string calldata description)
        external
        onlyRole(NGO_MANAGER_ROLE)
        whenNotPaused
    {
        if (ngo == address(0)) revert Errors.InvalidNGOAddress();
        if (isApproved[ngo]) revert Errors.NGOAlreadyApproved();
        if (bytes(name).length == 0) revert Errors.InvalidConfiguration();

        isApproved[ngo] = true;
        ngoInfo[ngo] = NGOInfo({
            name: name,
            description: description,
            approvalTime: block.timestamp,
            totalReceived: 0,
            isActive: true
        });

        approvedNGOs.push(ngo);
        totalApprovedNGOs++;

        // Set as current NGO if none is set
        if (currentNGO == address(0)) {
            currentNGO = ngo;
            emit CurrentNGOSet(address(0), ngo);
        }

        emit NGOApproved(ngo, name, block.timestamp);
    }

    /**
     * @dev Removes an NGO from approved list
     * @param ngo The NGO address to remove
     */
    function removeNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE) {
        if (!isApproved[ngo]) revert Errors.NGONotApproved();

        string memory name = ngoInfo[ngo].name;

        isApproved[ngo] = false;
        ngoInfo[ngo].isActive = false;
        totalApprovedNGOs--;

        // Remove from array
        _removeFromArray(ngo);

        // Update current NGO if this was the current one
        if (currentNGO == ngo) {
            currentNGO = approvedNGOs.length > 0 ? approvedNGOs[0] : address(0);
            emit CurrentNGOSet(ngo, currentNGO);
        }

        emit NGORemoved(ngo, name, block.timestamp);
    }

    /**
     * @dev Updates NGO information
     * @param ngo The NGO address
     * @param name New name
     * @param description New description
     */
    function updateNGO(address ngo, string calldata name, string calldata description)
        external
        onlyRole(NGO_MANAGER_ROLE)
    {
        if (!isApproved[ngo]) revert Errors.NGONotApproved();
        if (bytes(name).length == 0) revert Errors.InvalidConfiguration();

        ngoInfo[ngo].name = name;
        ngoInfo[ngo].description = description;

        emit NGOUpdated(ngo, name, description);
    }

    /**
     * @dev Sets the current NGO for donations
     * @param ngo The NGO address to set as current
     */
    function setCurrentNGO(address ngo) external onlyRole(NGO_MANAGER_ROLE) {
        if (ngo != address(0) && !isApproved[ngo]) {
            revert Errors.NGONotApproved();
        }

        address oldNGO = currentNGO;
        currentNGO = ngo;

        emit CurrentNGOSet(oldNGO, ngo);
    }

    // === Donation Tracking ===

    /**
     * @dev Records a donation to an NGO (called by DonationRouter)
     * @param ngo The NGO that received the donation
     * @param amount The donation amount
     */
    function recordDonation(address ngo, uint256 amount) external onlyRole(DONATION_RECORDER_ROLE) {
        if (!isApproved[ngo]) revert Errors.NGONotApproved();
        if (amount == 0) revert Errors.InvalidAmount();

        ngoInfo[ngo].totalReceived += amount;

        emit DonationRecorded(ngo, amount);
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
        address[] memory activeNGOs = new address[](totalApprovedNGOs);
        uint256 count = 0;

        for (uint256 i = 0; i < approvedNGOs.length; i++) {
            if (isApproved[approvedNGOs[i]]) {
                activeNGOs[count] = approvedNGOs[i];
                count++;
            }
        }

        // Resize array to actual count
        assembly {
            mstore(activeNGOs, count)
        }

        return activeNGOs;
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
        for (uint256 i = 0; i < approvedNGOs.length; i++) {
            if (isApproved[approvedNGOs[i]]) {
                totalDonated += ngoInfo[approvedNGOs[i]].totalReceived;
            }
        }

        return (totalApprovedNGOs, currentNGO, totalDonated);
    }

    // === Internal Functions ===

    /**
     * @dev Removes an NGO from the approved array
     * @param ngo The NGO address to remove
     */
    function _removeFromArray(address ngo) internal {
        for (uint256 i = 0; i < approvedNGOs.length; i++) {
            if (approvedNGOs[i] == ngo) {
                approvedNGOs[i] = approvedNGOs[approvedNGOs.length - 1];
                approvedNGOs.pop();
                break;
            }
        }
    }

    // === Emergency Functions ===

    /**
     * @dev Emergency pause of the registry
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the registry
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
