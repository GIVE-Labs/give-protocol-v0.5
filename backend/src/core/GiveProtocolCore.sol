// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IACLManager.sol";
import "../storage/StorageLib.sol";
import "../modules/VaultModule.sol";
import "../modules/AdapterModule.sol";
import "../modules/DonationModule.sol";
import "../modules/SyntheticModule.sol";
import "../modules/RiskModule.sol";
import "../modules/EmergencyModule.sol";
import "../synthetic/SyntheticLogic.sol";
import "../vault/GiveVault4626.sol";

/// @title GiveProtocolCore
/// @notice Thin orchestration layer that delegates lifecycle operations to module libraries.
contract GiveProtocolCore is Initializable, UUPSUpgradeable {
    IACLManager public aclManager;

    event Initialized(address indexed acl, address indexed caller);

    modifier onlyRole(bytes32 roleId) {
        if (!aclManager.hasRole(roleId, msg.sender)) {
            revert Unauthorized(roleId, msg.sender);
        }
        _;
    }

    error Unauthorized(bytes32 roleId, address account);

    bytes32 public constant ROLE_UPGRADER = keccak256("ROLE_UPGRADER");

    function initialize(address _aclManager) external initializer {
        if (_aclManager == address(0)) revert Unauthorized(ROLE_UPGRADER, address(0));
        aclManager = IACLManager(_aclManager);

        GiveTypes.SystemConfig storage sys = StorageLib.system();
        sys.aclManager = _aclManager;
        sys.initialized = true;
        sys.version += 1;
        sys.lastBootstrapAt = uint64(block.timestamp);

        emit Initialized(_aclManager, msg.sender);
    }

    // === Module entrypoints ===

    function configureVault(bytes32 vaultId, VaultModule.VaultConfigInput memory cfg)
        external
        onlyRole(VaultModule.MANAGER_ROLE)
    {
        VaultModule.configure(vaultId, cfg);
    }

    function configureAdapter(bytes32 adapterId, AdapterModule.AdapterConfigInput memory cfg)
        external
        onlyRole(AdapterModule.MANAGER_ROLE)
    {
        AdapterModule.configure(adapterId, cfg);
    }

    function configureDonation(bytes32 donationId, DonationModule.DonationConfigInput memory cfg)
        external
        onlyRole(DonationModule.MANAGER_ROLE)
    {
        DonationModule.configure(donationId, cfg);
    }

    function configureSynthetic(bytes32 syntheticId, SyntheticModule.SyntheticConfigInput memory cfg)
        external
        onlyRole(SyntheticModule.MANAGER_ROLE)
    {
        SyntheticModule.configure(syntheticId, cfg);
    }

    function mintSynthetic(bytes32 syntheticId, address account, uint256 amount)
        external
        onlyRole(SyntheticModule.MANAGER_ROLE)
    {
        SyntheticLogic.mint(syntheticId, account, amount);
    }

    function burnSynthetic(bytes32 syntheticId, address account, uint256 amount)
        external
        onlyRole(SyntheticModule.MANAGER_ROLE)
    {
        SyntheticLogic.burn(syntheticId, account, amount);
    }

    function getAdapterConfig(bytes32 adapterId)
        external
        view
        returns (address assetAddress, address vaultAddress, GiveTypes.AdapterKind kind, bool active)
    {
        GiveTypes.AdapterConfig storage cfg = StorageLib.adapter(adapterId);
        return (cfg.asset, cfg.vault, cfg.kind, cfg.active);
    }

    function getSyntheticBalance(bytes32 syntheticId, address account) external view returns (uint256) {
        return StorageLib.syntheticState(syntheticId).balances[account];
    }

    function getSyntheticTotalSupply(bytes32 syntheticId) external view returns (uint256) {
        return StorageLib.syntheticState(syntheticId).totalSupply;
    }

    function getSyntheticConfig(bytes32 syntheticId)
        external
        view
        returns (address proxy, address asset, bool active)
    {
        GiveTypes.SyntheticAsset storage syntheticAsset = StorageLib.syntheticState(syntheticId);
        return (syntheticAsset.proxy, syntheticAsset.asset, syntheticAsset.active);
    }

    function configureRisk(bytes32 riskId, RiskModule.RiskConfigInput memory cfg)
        external
        onlyRole(RiskModule.MANAGER_ROLE)
    {
        RiskModule.configure(riskId, cfg);
    }

    function assignVaultRisk(bytes32 vaultId, bytes32 riskId) external onlyRole(RiskModule.MANAGER_ROLE) {
        GiveTypes.VaultConfig storage vaultCfg = StorageLib.vault(vaultId);
        RiskModule.assignVaultRisk(vaultId, riskId);
        address vaultProxy = vaultCfg.proxy;
        if (vaultProxy != address(0)) {
            GiveTypes.RiskConfig storage riskCfg = StorageLib.ensureRiskConfig(riskId);
            GiveVault4626(payable(vaultProxy)).syncRiskLimits(riskId, riskCfg.maxDeposit, riskCfg.maxBorrow);
        }
    }

    function triggerEmergency(bytes32 vaultId, EmergencyModule.EmergencyAction action, bytes calldata data)
        external
        onlyRole(keccak256("EMERGENCY_ROLE"))
    {
        EmergencyModule.execute(vaultId, action, data);
    }

    function getRiskConfig(bytes32 riskId) external view returns (GiveTypes.RiskConfig memory) {
        return StorageLib.riskConfig(riskId);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal view override {
        if (!aclManager.hasRole(ROLE_UPGRADER, msg.sender)) {
            revert Unauthorized(ROLE_UPGRADER, msg.sender);
        }
    }
}
