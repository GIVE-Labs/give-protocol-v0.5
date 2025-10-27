// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../src/governance/ACLManager.sol";
import "../src/registry/StrategyRegistry.sol";
import "../src/registry/CampaignRegistry.sol";
import "../src/factory/CampaignVaultFactory.sol";
import "../src/vault/CampaignVault4626.sol";
import "../src/payout/PayoutRouter.sol";
import "../src/types/GiveTypes.sol";

contract CampaignVaultFactoryTest is Test {
    ACLManager internal acl;
    StrategyRegistry internal strategyRegistry;
    CampaignRegistry internal campaignRegistry;
    CampaignVaultFactory internal factory;
    PayoutRouter internal router;
    ERC20Mock internal asset;

    address internal admin;
    address internal upgrader;
    bytes32 internal strategyId;
    bytes32 internal campaignId;

    function setUp() public {
        admin = makeAddr("admin");
        upgrader = makeAddr("upgrader");
        strategyId = keccak256("strategy.prod");
        campaignId = keccak256("campaign.alpha");

        ACLManager aclImpl = new ACLManager();
        ERC1967Proxy aclProxy = new ERC1967Proxy(
            address(aclImpl),
            abi.encodeCall(ACLManager.initialize, (admin, upgrader))
        );
        acl = ACLManager(address(aclProxy));

        StrategyRegistry strategyImpl = new StrategyRegistry();
        ERC1967Proxy strategyProxy = new ERC1967Proxy(
            address(strategyImpl),
            abi.encodeCall(StrategyRegistry.initialize, (address(acl)))
        );
        strategyRegistry = StrategyRegistry(address(strategyProxy));

        CampaignRegistry campaignImpl = new CampaignRegistry();
        ERC1967Proxy campaignProxy = new ERC1967Proxy(
            address(campaignImpl),
            abi.encodeCall(
                CampaignRegistry.initialize,
                (address(acl), address(strategyRegistry))
            )
        );
        campaignRegistry = CampaignRegistry(address(campaignProxy));

        PayoutRouter routerImpl = new PayoutRouter();
        ERC1967Proxy routerProxy = new ERC1967Proxy(
            address(routerImpl),
            abi.encodeCall(
                PayoutRouter.initialize,
                (address(acl), address(campaignRegistry), admin, admin, 250)
            )
        );
        router = PayoutRouter(payable(address(routerProxy)));

        // Deploy vault implementation for cloning
        CampaignVault4626 vaultImpl = new CampaignVault4626(
            IERC20(address(asset)),
            "",
            "",
            address(1)
        );

        CampaignVaultFactory factoryImpl = new CampaignVaultFactory();
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeCall(
                CampaignVaultFactory.initialize,
                (
                    address(acl),
                    address(campaignRegistry),
                    address(strategyRegistry),
                    address(router),
                    address(vaultImpl)
                )
            )
        );
        factory = CampaignVaultFactory(address(factoryProxy));

        vm.startPrank(admin);
        acl.grantRole(acl.strategyAdminRole(), admin);
        acl.grantRole(acl.campaignAdminRole(), admin);
        acl.grantRole(acl.campaignCreatorRole(), admin);
        acl.grantRole(acl.campaignCuratorRole(), admin);
        acl.grantRole(acl.strategyAdminRole(), address(factory));
        acl.grantRole(acl.campaignAdminRole(), address(factory));
        acl.createRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.createRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), admin);
        acl.grantRole(router.FEE_MANAGER_ROLE(), admin);
        acl.grantRole(router.VAULT_MANAGER_ROLE(), address(factory));
        vm.stopPrank();

        asset = new ERC20Mock();
        asset.mint(admin, 1_000_000e18);

        vm.prank(admin);
        strategyRegistry.registerStrategy(
            StrategyRegistry.StrategyInput({
                id: strategyId,
                adapter: makeAddr("adapter"),
                riskTier: bytes32("tier.core"),
                maxTvl: 5_000_000e18,
                metadataHash: keccak256("metadata")
            })
        );

        CampaignRegistry.CampaignInput memory input = CampaignRegistry
            .CampaignInput({
                id: campaignId,
                payoutRecipient: admin,
                strategyId: strategyId,
                metadataHash: keccak256("campaign.metadata"),
                metadataCID: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                targetStake: 1_000_000e18,
                minStake: 100_000e18,
                fundraisingStart: uint64(block.timestamp),
                fundraisingEnd: uint64(block.timestamp + 30 days)
            });

        vm.deal(admin, 1 ether);
        vm.prank(admin);
        campaignRegistry.submitCampaign{value: 0.005 ether}(input);
        vm.prank(admin);
        campaignRegistry.approveCampaign(campaignId, admin);
    }

    function testDeployCampaignVaultRegistersWithRegistries() public {
        CampaignVaultFactory.DeployParams memory params = CampaignVaultFactory
            .DeployParams({
                campaignId: campaignId,
                strategyId: strategyId,
                lockProfile: keccak256("lock.weekly"),
                asset: address(asset),
                admin: admin,
                name: "Campaign Vault",
                symbol: "cVAULT"
            });

        vm.prank(admin);
        address vaultAddr = factory.deployCampaignVault(params);
        assertTrue(vaultAddr != address(0));

        CampaignVault4626 vault = CampaignVault4626(payable(vaultAddr));
        assertTrue(vault.campaignInitialized());

        (
            bytes32 campaignId_,
            bytes32 strategyId_,
            bytes32 lockProfile_,
            address factoryAddr
        ) = vault.getCampaignMetadata();
        assertEq(campaignId_, campaignId);
        assertEq(strategyId_, strategyId);
        assertEq(lockProfile_, params.lockProfile);
        assertEq(factoryAddr, address(factory));

        GiveTypes.CampaignConfig memory campaignCfg = campaignRegistry
            .getCampaign(campaignId);
        assertEq(campaignCfg.vault, vaultAddr);
        assertEq(campaignCfg.lockProfile, params.lockProfile);

        address[] memory linkedVaults = strategyRegistry.getStrategyVaults(
            strategyId
        );
        assertEq(linkedVaults.length, 1);
        assertEq(linkedVaults[0], vaultAddr);

        // TODO Phase 18: Restore when adding EIP-1167 clones with predictDeployment()
        // address recorded = factory.getDeployment(campaignId, strategyId, params.lockProfile);
        // assertEq(recorded, vault, "Deployment should be recorded");
    }

    function testDeployCampaignVaultRejectsDuplicateCombination() public {
        CampaignVaultFactory.DeployParams memory params = CampaignVaultFactory
            .DeployParams({
                campaignId: campaignId,
                strategyId: strategyId,
                lockProfile: bytes32("lock.standard"),
                asset: address(asset),
                admin: admin,
                name: "Campaign Vault",
                symbol: "cVAULT"
            });

        vm.prank(admin);
        factory.deployCampaignVault(params);

        bytes32 key = keccak256(
            abi.encodePacked(
                params.campaignId,
                params.strategyId,
                params.lockProfile
            )
        );
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                CampaignVaultFactory.DeploymentExists.selector,
                key
            )
        );
        factory.deployCampaignVault(params);
    }
}
