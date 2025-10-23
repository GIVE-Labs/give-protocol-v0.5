// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/core/GiveProtocolCore.sol";
import "../src/governance/ACLManager.sol";
import "../src/modules/AdapterModule.sol";
import "../src/types/GiveTypes.sol";

import "../src/adapters/kinds/CompoundingAdapter.sol";
import "../src/adapters/kinds/ClaimableYieldAdapter.sol";
import "../src/adapters/kinds/GrowthAdapter.sol";
import "../src/adapters/kinds/PTAdapter.sol";

contract AdapterSuiteTest is Test {
    using SafeERC20 for IERC20;

    ACLManager internal acl;
    GiveProtocolCore internal core;
    MockAsset internal asset;
    address internal vault;

    function setUp() public {
        asset = new MockAsset();
        vault = makeAddr("vault");

        ACLManager implementation = new ACLManager();
        ERC1967Proxy aclProxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(ACLManager.initialize.selector, address(this), address(this))
        );
        acl = ACLManager(address(aclProxy));

        GiveProtocolCore coreImpl = new GiveProtocolCore();
        ERC1967Proxy coreProxy = new ERC1967Proxy(address(coreImpl), "");
        core = GiveProtocolCore(address(coreProxy));
        core.initialize(address(acl));

        acl.createRole(AdapterModule.MANAGER_ROLE, address(this));
        acl.grantRole(AdapterModule.MANAGER_ROLE, address(this));
        acl.grantRole(core.ROLE_UPGRADER(), address(this));
    }

    function testCompoundingAdapter() public {
        bytes32 adapterId = keccak256("comp-adapter");
        _configureAdapter(adapterId, GiveTypes.AdapterKind.CompoundingValue);

        CompoundingAdapter adapter = new CompoundingAdapter(adapterId, address(asset), vault);
        assertEq(adapter.adapterId(), adapterId);
        assertEq(adapter.vault(), vault);
        assertEq(address(adapter.asset()), address(asset));
        asset.mint(address(adapter), 5_000e6);

        vm.prank(vault);
        adapter.invest(5_000e6);

        assertEq(adapter.totalAssets(), 5_000e6);

        asset.mint(address(adapter), 1_000e6);
        assertEq(asset.balanceOf(vault), 0);
        vm.prank(vault);
        adapter.harvest();
        assertEq(asset.balanceOf(vault), 1_000e6);
    }

    function testClaimableAdapter() public {
        bytes32 adapterId = keccak256("claimable");
        _configureAdapter(adapterId, GiveTypes.AdapterKind.ClaimableYield);

        ClaimableYieldAdapter adapter = new ClaimableYieldAdapter(adapterId, address(asset), vault);
        assertEq(adapter.vault(), vault);
        asset.mint(address(adapter), 5_000e6);

        vm.prank(vault);
        adapter.invest(5_000e6);

        asset.mint(address(this), 1_000e6);
        asset.approve(address(adapter), type(uint256).max);
        adapter.queueYield(500e6);

        vm.prank(vault);
        adapter.harvest();
        assertEq(asset.balanceOf(vault), 500e6);
    }

    function testGrowthAdapter() public {
        bytes32 adapterId = keccak256("growth");
        _configureAdapter(adapterId, GiveTypes.AdapterKind.BalanceGrowth);

        GrowthAdapter adapter = new GrowthAdapter(adapterId, address(asset), vault);
        assertEq(adapter.vault(), vault);
        asset.mint(address(adapter), 5_000e6);

        vm.prank(vault);
        adapter.invest(5_000e6);

        adapter.setGrowthIndex(2e18);
        assertEq(adapter.totalAssets(), 10_000e6);
    }

    function testPTAdapter() public {
        bytes32 adapterId = keccak256("pt");
        _configureAdapter(adapterId, GiveTypes.AdapterKind.PerpetualYieldToken);

        PTAdapter adapter =
            new PTAdapter(adapterId, address(asset), vault, uint64(block.timestamp), uint64(block.timestamp + 30 days));
        assertEq(adapter.vault(), vault);
        vm.prank(vault);
        adapter.rollover(uint64(block.timestamp + 1 days), uint64(block.timestamp + 31 days));
        (, uint64 maturity) = adapter.currentSeries();
        assertEq(maturity, uint64(block.timestamp + 31 days));
    }

    function _configureAdapter(bytes32 adapterId, GiveTypes.AdapterKind kind) internal {
        core.configureAdapter(
            adapterId,
            AdapterModule.AdapterConfigInput({
                id: adapterId,
                proxy: address(0),
                implementation: address(0),
                asset: address(asset),
                vault: vault,
                kind: kind,
                metadataHash: bytes32(0)
            })
        );

        (, address storedVault,, bool active) = core.getAdapterConfig(adapterId);
        assertEq(storedVault, vault);
        assertTrue(active);
    }
}

contract MockAsset is ERC20 {
    constructor() ERC20("Mock", "MOCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
