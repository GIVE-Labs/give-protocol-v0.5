// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/donation/DonationRouter.sol";
import "../src/donation/NGORegistry.sol";
import "../src/utils/Errors.sol";
import "../src/access/RoleManager.sol";

contract RouterTest is Test {
    DonationRouter public router;
    NGORegistry public registry;
    MockERC20 public usdc;
    RoleManager public roleManager;

    address public admin;
    address public caller;
    address public ngo1;
    address public ngo2;
    address public feeRecipient;

    function setUp() public {
        admin = makeAddr("admin");
        caller = makeAddr("caller");
        ngo1 = makeAddr("ngo1");
        ngo2 = makeAddr("ngo2");
        feeRecipient = makeAddr("fee");

        usdc = new MockERC20("Test USDC", "TUSDC", 6);
        usdc.mint(address(this), 1_000_000e6);

        roleManager = new RoleManager(address(this));
        roleManager.grantRole(roleManager.ROLE_VAULT_OPS(), admin);
        roleManager.grantRole(roleManager.ROLE_TREASURY(), admin);
        roleManager.grantRole(roleManager.ROLE_GUARDIAN(), admin);
        roleManager.grantRole(roleManager.ROLE_CAMPAIGN_ADMIN(), admin);

        registry = new NGORegistry(address(roleManager));
        router = new DonationRouter(address(roleManager), address(registry), feeRecipient, admin, 0);
        roleManager.grantRole(roleManager.ROLE_DONATION_RECORDER(), address(router));

        vm.startPrank(admin);
        registry.addNGO(ngo1, "NGO1", bytes32("kyc1"), admin);
        registry.addNGO(ngo2, "NGO2", bytes32("kyc2"), admin);
        router.setAuthorizedCaller(caller, true);
        vm.stopPrank();
    }

    function testUpdateFeeConfig() public {
        vm.prank(admin);
        router.updateFeeConfig(feeRecipient, 250); // 2.5%
        (address r, uint256 bps,) = router.getFeeConfig();
        assertEq(r, feeRecipient);
        assertEq(bps, 250);
    }

    function testDistributeToCurrentNGO() public {
        // Current NGO is ngo1 after first add
        usdc.transfer(address(router), 10_000e6);
        vm.prank(caller);
        (uint256 donated, uint256 fee) = router.distribute(address(usdc), 10_000e6);
        assertEq(fee, 0);
        assertEq(donated, 10_000e6);
        assertEq(usdc.balanceOf(ngo1), 10_000e6);
    }

    function testDistributeToMultiple() public {
        usdc.transfer(address(router), 9_000e6);
        address[] memory ngos = new address[](2);
        ngos[0] = ngo1;
        ngos[1] = ngo2;
        vm.prank(caller);
        (uint256 totalDonated, uint256 fee) = router.distributeToMultiple(address(usdc), 9_000e6, ngos);
        assertEq(fee, 0);
        assertEq(totalDonated, 9_000e6);
        assertEq(usdc.balanceOf(ngo1), 4_500e6);
        assertEq(usdc.balanceOf(ngo2), 4_500e6);
    }

    function testUnauthorizedCallerCannotDistribute() public {
        usdc.transfer(address(router), 1_000e6);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnauthorizedCaller.selector, address(this)));
        router.distribute(address(usdc), 1_000e6);
    }
}

contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _decimals = d;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
