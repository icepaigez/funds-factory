// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CrowdFund} from "../src/CrowdFund.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FundFactory} from "../src/FundFactory.sol";
import {MockPrizeVault} from "../test/mocks/MockPrizeVault.sol";

contract DeployCrowdFund is Script {
    function run()
        external
        returns (
            address,
            CrowdFund,
            address,
            address,
            address,
            address,
            address,
            address,
            address,
            address,
            address
        )
    {
        HelperConfig helperConfig = new HelperConfig();
        FundFactory fundFactory = new FundFactory(msg.sender);

        (
            address priceFeed,
            address prizeVault,
            address prizePool,
            address swapContract
        ) = helperConfig.deployConfig();
        (
            address weth,
            address usdc,
            address uniswapV3factory,
            address poolPair
        ) = helperConfig.mockConfigs();

        vm.startBroadcast();
        CrowdFund crowdfund = new CrowdFund(msg.sender, address(fundFactory));

        vm.stopBroadcast();

        return (
            msg.sender,
            crowdfund,
            address(fundFactory),
            prizeVault,
            priceFeed,
            weth,
            usdc,
            uniswapV3factory,
            prizePool,
            swapContract,
            poolPair
        );
    }
}
