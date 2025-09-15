// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        address usdc;
        address aavePool;
        uint256 deployerKey;
    }

    function getActiveNetworkConfig() public view returns (address, address, address, address, address, address, uint256) {
        return (
            activeNetworkConfig.wethUsdPriceFeed,
            activeNetworkConfig.wbtcUsdPriceFeed,
            activeNetworkConfig.weth,
            activeNetworkConfig.wbtc,
            activeNetworkConfig.usdc,
            activeNetworkConfig.aavePool,
            activeNetworkConfig.deployerKey
        );
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            usdc: 0xA0b86a33E6417C8f2C8B2E5C5B5C5E5E5E5E5e5e, // Sepolia USDC mock
            aavePool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951, // Sepolia Aave Pool
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock();
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock();
        ERC20Mock usdcMock = new ERC20Mock();
        
        // Mint initial tokens to deployer
        wethMock.mint(msg.sender, 1000e18); // 1000 WETH
        wbtcMock.mint(msg.sender, 1000e8);  // 1000 WBTC
        usdcMock.mint(msg.sender, 1000000e6); // 1M USDC with 6 decimals
        
        // For Anvil, we'll use a mock address for Aave Pool since we'll use MockYieldAdapter
        address mockAavePool = address(0x1234567890123456789012345678901234567890);
        
        vm.stopBroadcast();
        return NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            usdc: address(usdcMock),
            aavePool: mockAavePool,
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}