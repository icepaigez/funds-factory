// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockAggregatorV3.sol";

contract HelperConfig is Script {
    NetworkConfig public deployConfig;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 3689.99e8;
    uint256 public constant SEPOLIA_CHAINID = 11155111;
    uint256 public constant ETH_MAINNET_CHAINID = 1;
    address public constant SEPOLIA_PRICE_FEED_ADDRESS =
        0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant ETH_MAINNET_PRICE_FEED_ADDRESS =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant SEPOLIA_PRIZE_VAULT_ADDRESS =
        0x95849a4C2E58F4f8Bf868ADEf10B05747A24eE71;
    address public constant SEPOLIA_PRIZE_POOL_ADDRESS =
        0x122FecA66c2b1Ba8Fa9C39E88152592A5496Bc99;
    address public constant ETH_MAINNET_PRIZE_VAULT_ADDRESS = address(1);
    address public constant ETH_MAINNET_PRIZE_POOL_ADDRESS = address(1);
    address public constant SEPOLIA_SWAP_CONTRACT_ADDRESS = address(0x123);
    address public constant ETH_MAINNET_SWAP_CONTRACT_ADDRESS = address(1);

    constructor() {
        if (block.chainid == SEPOLIA_CHAINID) {
            deployConfig = getSepoliaConfig();
        } else if (block.chainid == ETH_MAINNET_CHAINID) {
            deployConfig = getETHMainnetConfig();
        } else {
            deployConfig = getOrCreateAnvilConfig();
        }
    }

    struct NetworkConfig {
        address priceFeed;
        address prizeVault;
        address prizePool;
        address swapContract;
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            priceFeed: SEPOLIA_PRICE_FEED_ADDRESS,
            prizeVault: SEPOLIA_PRIZE_VAULT_ADDRESS,
            prizePool: SEPOLIA_PRIZE_POOL_ADDRESS,
            swapContract: SEPOLIA_SWAP_CONTRACT_ADDRESS
        });
        return config;
    }

    function getETHMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            priceFeed: ETH_MAINNET_PRICE_FEED_ADDRESS,
            prizeVault: ETH_MAINNET_PRIZE_VAULT_ADDRESS,
            prizePool: ETH_MAINNET_PRIZE_POOL_ADDRESS,
            swapContract: ETH_MAINNET_SWAP_CONTRACT_ADDRESS
        });
        return config;
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (deployConfig.priceFeed != address(0)) {
            return deployConfig;
        }
        NetworkConfig memory config;
        vm.startBroadcast();
        MockV3Aggregator priceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );

        config = NetworkConfig({
            priceFeed: address(priceFeed),
            prizeVault: address(0),
            prizePool: address(0),
            swapContract: address(0)
        });
        vm.stopBroadcast();
        return config;
    }
}
