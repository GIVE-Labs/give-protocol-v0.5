// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NGORegistry.sol";
import "../src/MockYieldVault.sol";
import "../src/MorphImpactStaking.sol";
import "../src/YieldDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock tokens for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**6); // 1M USDC
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped ETH", "WETH") {
        _mint(msg.sender, 1000000 * 10**18); // 1M WETH
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Mock Tokens
        MockUSDC usdc = new MockUSDC();
        console.log("MockUSDC deployed at:", address(usdc));
        
        MockWETH weth = new MockWETH();
        console.log("MockWETH deployed at:", address(weth));
        
        // Deploy NGO Registry
        NGORegistry ngoRegistry = new NGORegistry();
        console.log("NGORegistry deployed at:", address(ngoRegistry));
        
        // Deploy Mock Yield Vault
        MockYieldVault vault = new MockYieldVault();
        console.log("MockYieldVault deployed at:", address(vault));
        
        // Deploy Main Staking Contract
        MorphImpactStaking staking = new MorphImpactStaking(
            address(ngoRegistry), 
            address(vault)
        );
        console.log("MorphImpactStaking deployed at:", address(staking));
        
        // Deploy Yield Distributor
        YieldDistributor distributor = new YieldDistributor(
            address(ngoRegistry),
            address(staking)
        );
        console.log("YieldDistributor deployed at:", address(distributor));
        
        // Setup vault with tokens
        vault.addSupportedToken(address(usdc), 1000); // 10% APY
        vault.addSupportedToken(address(weth), 800);  // 8% APY
        
        // Setup staking with tokens
        staking.addSupportedToken(address(usdc));
        staking.addSupportedToken(address(weth));
        
        // Grant roles
        ngoRegistry.grantRole(ngoRegistry.VERIFIER_ROLE(), deployer);
        
        // Deployer mints some tokens for testing
        usdc.mint(deployer, 10000 * 10**6); // 10k USDC
        weth.mint(deployer, 100 * 10**18);  // 100 WETH
        
        // Setup vault with initial liquidity
        usdc.transfer(address(vault), 50000 * 10**6);
        weth.transfer(address(vault), 50 * 10**18);
        
        // Register mock NGOs
        string[] memory causes1 = new string[](3);
        causes1[0] = "Education";
        causes1[1] = "Technology";
        causes1[2] = "Children";
        
        string[] memory causes2 = new string[](3);
        causes2[0] = "Environment";
        causes2[1] = "Health";
        causes2[2] = "Water";
        
        string[] memory causes3 = new string[](3);
        causes3[0] = "Health";
        causes3[1] = "Technology";
        causes3[2] = "Community";
        
        // Register Education For All
        ngoRegistry.registerNGO(
            "Education For All",
            "Providing quality education to underprivileged children worldwide through innovative digital learning platforms and community-based programs.",
            "https://educationforall.org",
            "https://via.placeholder.com/150/667eea/ffffff?text=EFA",
            address(0x1234567890123456789012345678901234567890),
            causes1,
            "ipfs://educationforall"
        );
        
        // Register Clean Water Initiative
        ngoRegistry.registerNGO(
            "Clean Water Initiative",
            "Bringing clean and safe drinking water to communities in need through sustainable water purification systems and infrastructure development.",
            "https://cleanwaterinitiative.org",
            "https://via.placeholder.com/150/764ba2/ffffff?text=CWI",
            address(0x2345678901234567890123456789012345678901),
            causes2,
            "ipfs://cleanwater"
        );
        
        // Register HealthCare Access
        ngoRegistry.registerNGO(
            "HealthCare Access",
            "Ensuring equitable access to healthcare services in underserved communities through mobile clinics and telemedicine solutions.",
            "https://healthcareaccess.org",
            "https://via.placeholder.com/150/f093fb/ffffff?text=HCA",
            address(0x3456789012345678901234567890123456789012),
            causes3,
            "ipfs://healthcareaccess"
        );
        
        // Verify NGOs
        ngoRegistry.verifyNGO(address(0x1234567890123456789012345678901234567890));
        ngoRegistry.verifyNGO(address(0x2345678901234567890123456789012345678901));
        ngoRegistry.verifyNGO(address(0x3456789012345678901234567890123456789012));
        
        vm.stopBroadcast();
    }
}