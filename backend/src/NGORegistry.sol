// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title NGORegistry
 * @dev Registry for managing and verifying NGOs in the MorphImpact platform
 */
contract NGORegistry is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct NGO {
        string name;
        string description;
        string website;
        string logoURI;
        address walletAddress;
        bool isVerified;
        bool isActive;
        uint256 totalYieldReceived;
        uint256 activeStakers;
        string[] causes;
        uint256 reputationScore;
        uint256 registrationTime;
        string metadataHash;
    }

    struct CauseDeviation {
        bool isFlagged;
        string reason;
        uint256 timestamp;
        address reporter;
    }

    mapping(address => NGO) public ngos;
    mapping(address => CauseDeviation) public causeDeviations;
    mapping(address => bool) public hasRegistered;
    
    address[] public ngoAddresses;
    uint256 public totalNGOs;
    uint256 public minReputationScore = 70;
    uint256 public maxReputationScore = 100;

    // Events
    event NGORegistered(
        address indexed ngoAddress,
        string name,
        string[] causes,
        uint256 registrationTime
    );

    event NGOVerified(address indexed ngoAddress, bool isVerified);
    event NGOUpdated(address indexed ngoAddress, string name, string[] causes);
    event CauseDeviationFlagged(
        address indexed ngoAddress,
        string reason,
        address reporter,
        uint256 timestamp
    );
    event ReputationScoreUpdated(
        address indexed ngoAddress,
        uint256 newScore,
        uint256 oldScore
    );

    // Custom errors
    error NGOAlreadyRegistered();
    error InvalidNGOAddress();
    error InvalidName();
    error InvalidWebsite();
    error EmptyCauses();
    error NGOAlreadyVerified();
    error NGONotRegistered();
    error InvalidReputationScore();
    error NotAuthorized();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }

    /**
     * @dev Register a new NGO in the system
     * @param _name Name of the NGO
     * @param _description Description of the NGO
     * @param _website Website URL
     * @param _logoURI Logo URI/IPFS hash
     * @param _walletAddress Wallet address for receiving funds
     * @param _causes Array of causes this NGO supports
     * @param _metadataHash IPFS hash containing additional metadata
     */
    function registerNGO(
        string calldata _name,
        string calldata _description,
        string calldata _website,
        string calldata _logoURI,
        address _walletAddress,
        string[] calldata _causes,
        string calldata _metadataHash
    ) external whenNotPaused nonReentrant {
        if (hasRegistered[_walletAddress]) revert NGOAlreadyRegistered();
        if (_walletAddress == address(0)) revert InvalidNGOAddress();
        if (bytes(_name).length == 0) revert InvalidName();
        if (bytes(_website).length == 0) revert InvalidWebsite();
        if (_causes.length == 0) revert EmptyCauses();

        // Create new NGO struct
        NGO storage newNGO = ngos[_walletAddress];
        newNGO.name = _name;
        newNGO.description = _description;
        newNGO.website = _website;
        newNGO.logoURI = _logoURI;
        newNGO.walletAddress = _walletAddress;
        newNGO.isVerified = false;
        newNGO.isActive = true;
        newNGO.totalYieldReceived = 0;
        newNGO.activeStakers = 0;
        newNGO.reputationScore = minReputationScore;
        newNGO.registrationTime = block.timestamp;
        newNGO.metadataHash = _metadataHash;
        
        // Copy causes array
        for (uint256 i = 0; i < _causes.length; i++) {
            newNGO.causes.push(_causes[i]);
        }

        ngoAddresses.push(_walletAddress);
        hasRegistered[_walletAddress] = true;
        totalNGOs++;

        emit NGORegistered(_walletAddress, _name, _causes, block.timestamp);
    }

    /**
     * @dev Verify an NGO by admin/verifier
     * @param _ngoAddress Address of the NGO to verify
     */
    function verifyNGO(address _ngoAddress) external onlyRole(VERIFIER_ROLE) {
        if (!hasRegistered[_ngoAddress]) revert NGONotRegistered();
        if (ngos[_ngoAddress].isVerified) revert NGOAlreadyVerified();

        ngos[_ngoAddress].isVerified = true;
        emit NGOVerified(_ngoAddress, true);
    }

    /**
     * @dev Update NGO information
     * @param _ngoAddress Address of the NGO to update
     * @param _name New name
     * @param _description New description
     * @param _website New website
     * @param _logoURI New logo URI
     * @param _causes New causes array
     * @param _metadataHash New metadata hash
     */
    function updateNGOInfo(
        address _ngoAddress,
        string calldata _name,
        string calldata _description,
        string calldata _website,
        string calldata _logoURI,
        string[] calldata _causes,
        string calldata _metadataHash
    ) external whenNotPaused nonReentrant {
        if (!hasRegistered[_ngoAddress]) revert NGONotRegistered();
        if (msg.sender != _ngoAddress && !hasRole(ADMIN_ROLE, msg.sender))
            revert NotAuthorized();
        if (bytes(_name).length == 0) revert InvalidName();
        if (bytes(_website).length == 0) revert InvalidWebsite();
        if (_causes.length == 0) revert EmptyCauses();

        NGO storage ngo = ngos[_ngoAddress];
        ngo.name = _name;
        ngo.description = _description;
        ngo.website = _website;
        ngo.logoURI = _logoURI;
        ngo.metadataHash = _metadataHash;
        
        // Update causes array
        delete ngo.causes;
        for (uint256 i = 0; i < _causes.length; i++) {
            ngo.causes.push(_causes[i]);
        }

        emit NGOUpdated(_ngoAddress, _name, _causes);
    }

    /**
     * @dev Flag an NGO for cause deviation
     * @param _ngoAddress Address of the NGO to flag
     * @param _reason Reason for flagging
     */
    function flagCauseDeviation(
        address _ngoAddress,
        string calldata _reason
    ) external onlyRole(VERIFIER_ROLE) {
        if (!hasRegistered[_ngoAddress]) revert NGONotRegistered();

        causeDeviations[_ngoAddress] = CauseDeviation({
            isFlagged: true,
            reason: _reason,
            timestamp: block.timestamp,
            reporter: msg.sender
        });

        emit CauseDeviationFlagged(_ngoAddress, _reason, msg.sender, block.timestamp);
    }

    /**
     * @dev Update NGO reputation score
     * @param _ngoAddress Address of the NGO
     * @param _newScore New reputation score (70-100)
     */
    function updateReputationScore(
        address _ngoAddress,
        uint256 _newScore
    ) external onlyRole(VERIFIER_ROLE) {
        if (!hasRegistered[_ngoAddress]) revert NGONotRegistered();
        if (_newScore < minReputationScore || _newScore > maxReputationScore)
            revert InvalidReputationScore();

        NGO storage ngo = ngos[_ngoAddress];
        uint256 oldScore = ngo.reputationScore;
        ngo.reputationScore = _newScore;

        emit ReputationScoreUpdated(_ngoAddress, _newScore, oldScore);
    }

    /**
     * @dev Get NGO details
     * @param _ngoAddress Address of the NGO
     * @return NGO struct with all details
     */
    function getNGO(address _ngoAddress) external view returns (NGO memory) {
        return ngos[_ngoAddress];
    }

    /**
     * @dev Get all registered NGOs
     * @return Array of all NGO addresses
     */
    function getAllNGOs() external view returns (address[] memory) {
        return ngoAddresses;
    }

    /**
     * @dev Get NGOs by verification status
     * @param _verified Whether to get verified or unverified NGOs
     * @return Array of NGO addresses matching the criteria
     */
    function getNGOsByVerification(bool _verified) external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < ngoAddresses.length; i++) {
            if (ngos[ngoAddresses[i]].isVerified == _verified) {
                count++;
            }
        }

        address[] memory filteredNGOs = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < ngoAddresses.length; i++) {
            if (ngos[ngoAddresses[i]].isVerified == _verified) {
                filteredNGOs[index] = ngoAddresses[i];
                index++;
            }
        }

        return filteredNGOs;
    }

    /**
     * @dev Check if an NGO is verified and active
     * @param _ngoAddress Address of the NGO
     * @return bool indicating if NGO is verified and active
     */
    function isVerifiedAndActive(address _ngoAddress) external view returns (bool) {
        return ngos[_ngoAddress].isVerified && ngos[_ngoAddress].isActive;
    }

    /**
     * @dev Update NGO staker count
     * @param _ngoAddress Address of the NGO
     * @param _increment Whether to increment or decrement
     */
    function updateStakerCount(
        address _ngoAddress,
        bool _increment
    ) external whenNotPaused {
        // Only callable by authorized contracts (GiveFiStaking)
        if (!hasRegistered[_ngoAddress]) revert NGONotRegistered();

        if (_increment) {
            ngos[_ngoAddress].activeStakers++;
        } else {
            if (ngos[_ngoAddress].activeStakers > 0) {
                ngos[_ngoAddress].activeStakers--;
            }
        }
    }

    /**
     * @dev Update total yield received by an NGO
     * @param _ngoAddress Address of the NGO
     * @param _amount Amount of yield received
     */
    function updateYieldReceived(
        address _ngoAddress,
        uint256 _amount
    ) external whenNotPaused {
        // Only callable by authorized contracts (YieldDistributor)
        if (!hasRegistered[_ngoAddress]) revert NGONotRegistered();

        ngos[_ngoAddress].totalYieldReceived += _amount;
    }

    /**
     * @dev Get cause deviation status
     * @param _ngoAddress Address of the NGO
     * @return isFlagged Whether the NGO is flagged for cause deviation
     * @return reason Reason for flagging
     * @return timestamp When it was flagged
     * @return reporter Who flagged it
     */
    function getCauseDeviation(
        address _ngoAddress
    ) external view returns (bool isFlagged, string memory reason, uint256 timestamp, address reporter) {
        CauseDeviation memory deviation = causeDeviations[_ngoAddress];
        return (deviation.isFlagged, deviation.reason, deviation.timestamp, deviation.reporter);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Set minimum reputation score
     * @param _newMinScore New minimum reputation score
     */
    function setMinReputationScore(uint256 _newMinScore) external onlyRole(ADMIN_ROLE) {
        minReputationScore = _newMinScore;
    }

    /**
     * @dev Set maximum reputation score
     * @param _newMaxScore New maximum reputation score
     */
    function setMaxReputationScore(uint256 _newMaxScore) external onlyRole(ADMIN_ROLE) {
        maxReputationScore = _newMaxScore;
    }
}