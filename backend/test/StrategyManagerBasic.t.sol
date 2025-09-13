// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/vault/GiveVault4626.sol";
import "../src/manager/StrategyManager.sol";
import "../src/adapters/IYieldAdapter.sol";

contract StrategyManagerBasicTest is Test {
    GiveVault4626 public vault;
    StrategyManager public manager;
    MockERC20 public usdc;
    MockAdapter public adapter;

    address public admin = address(0xA11CE);
    
    function setUp() public {
        usdc = new MockERC20("Test USDC", "TUSDC", 6);
        vault = new GiveVault4626(IERC20(address(usdc)), "GIVE USDC", "gvUSDC", admin);
        manager = new StrategyManager(address(vault), admin);
        adapter = new MockAdapter(IERC20(address(usdc)), address(vault));
    }

    function testApproveAndActivateAdapter() public {
        vm.prank(admin);
        manager.setAdapterApproval(address(adapter), true);
        vm.prank(admin);
        manager.setActiveAdapter(address(adapter));
        assertEq(address(vault.activeAdapter()), address(adapter));
    }

    function testUpdateVaultParameters() public {
        vm.prank(admin);
        manager.updateVaultParameters(200, 75, 100);
        (uint256 cash,, uint256 maxLoss,,) = vault.getConfiguration();
        assertEq(cash, 200);
        assertEq(maxLoss, 100);
    }

    function testSetDonationRouter() public {
        DonationRouter router = new DonationRouter(admin, address(new NGORegistry(admin)), address(0xFEE5), 100);
        vm.prank(admin);
        manager.setDonationRouter(address(router));
        assertEq(address(vault.donationRouter()), address(router));
    }
}

contract MockERC20 is ERC20 { 
    uint8 private _d; 
    constructor(string memory n, string memory s, uint8 d) ERC20(n,s){_d=d;} 
    function decimals() public view override returns (uint8){return _d;} 
}

contract MockAdapter is IYieldAdapter {
    IERC20 public override asset; address public override vault; uint256 public invested;
    constructor(IERC20 _a, address _v){asset=_a; vault=_v;}
    function totalAssets() external view override returns(uint256){return invested;}
    function invest(uint256 assets) external override { require(msg.sender==vault, "only vault"); invested+=assets; emit Invested(assets);} 
    function divest(uint256 assets) external override returns(uint256){ require(msg.sender==vault, "only vault"); emit Divested(assets, assets); return assets; }
    function harvest() external override returns(uint256,uint256){ require(msg.sender==vault, "only vault"); emit Harvested(0,0); return (0,0);} 
    function emergencyWithdraw() external override returns(uint256){ emit EmergencyWithdraw(0); return 0; }
}

