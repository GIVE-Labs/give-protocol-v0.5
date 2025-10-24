// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/adapters/AaveAdapter.sol";
import "../src/utils/GiveErrors.sol";

contract AaveAdapterBasicTest is Test {
    MockERC20 public usdc;
    MockAToken public aToken;
    MockAavePool public pool;
    AaveAdapter public adapter;

    address public admin;
    address public vault;

    function setUp() public {
        admin = makeAddr("admin");
        vault = makeAddr("vault");
        usdc = new MockERC20("Test USDC", "TUSDC", 6);
        aToken = new MockAToken("aUSDC", "aUSDC", 6, address(usdc));
        pool = new MockAavePool(address(usdc), address(aToken));
        vm.prank(admin);
        adapter = new AaveAdapter(address(usdc), vault, address(pool), admin);
        // Fund vault and pool
        usdc.mint(vault, 1_000_000e6);
        usdc.mint(address(pool), 1_000_000e6);
    }

    function testInvestDivestHarvest() public {
        // Move funds to adapter then invest
        vm.startPrank(vault);
        usdc.transfer(address(adapter), 100_000e6);
        adapter.invest(100_000e6);
        vm.stopPrank();

        assertEq(aToken.balanceOf(address(adapter)), 100_000e6);

        // Simulate yield by minting aTokens to adapter
        aToken.mint(address(adapter), 1_000e6);

        // Harvest
        vm.prank(vault);
        (uint256 profit, uint256 loss) = adapter.harvest();
        assertEq(profit, 1_000e6);
        assertEq(loss, 0);
        assertEq(usdc.balanceOf(vault), 1_000_000e6 + 1_000e6 - 100_000e6);

        // Divest some
        vm.prank(vault);
        uint256 returned = adapter.divest(50_000e6);
        assertEq(returned, 50_000e6);
        assertEq(usdc.balanceOf(vault), 1_000_000e6 + 1_000e6 - 100_000e6 + 50_000e6);
    }

    function testOnlyVaultCanInvest() public {
        vm.expectRevert(GiveErrors.OnlyVault.selector);
        adapter.invest(1);
    }
}

contract MockERC20 is ERC20 {
    uint8 private _d;

    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _d = d;
    }

    function decimals() public view override returns (uint8) {
        return _d;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockAToken is ERC20 {
    uint8 private _d;
    IERC20 public immutable underlyingAsset;

    constructor(string memory n, string memory s, uint8 d, address underlying) ERC20(n, s) {
        _d = d;
        underlyingAsset = IERC20(underlying);
    }

    function decimals() public view override returns (uint8) {
        return _d;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockAavePool {
    IERC20 public immutable asset;
    MockAToken public immutable aToken;

    constructor(address _asset, address _aToken) {
        asset = IERC20(_asset);
        aToken = MockAToken(_aToken);
    }

    function supply(address _asset, uint256 amount, address onBehalfOf, uint16) external {
        require(_asset == address(asset), "asset mismatch");
        asset.transferFrom(msg.sender, address(this), amount);
        aToken.mint(onBehalfOf, amount);
    }

    function withdraw(address _asset, uint256 amount, address to) external returns (uint256) {
        require(_asset == address(asset), "asset mismatch");
        aToken.burn(msg.sender, amount);
        asset.transfer(to, amount);
        return amount;
    }

    function getReserveData(address _asset) external view returns (ReserveData memory data) {
        require(_asset == address(asset), "asset mismatch");
        data.aTokenAddress = address(aToken);
    }
}
