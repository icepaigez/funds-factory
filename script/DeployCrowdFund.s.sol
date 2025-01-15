// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CrowdFund} from "../src/CrowdFund.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {FundFactory} from "../src/FundFactory.sol";
import {MockPoolToken} from "../test/mocks/MockPoolToken.sol";
import {MockPrizeVault} from "../test/mocks/MockPrizeVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployCrowdFund is Script {
    function run()
        external
        returns (address, CrowdFund, address, MockPoolToken, MockPrizeVault)
    {
        HelperConfig helperConfig = new HelperConfig();
        address deployer = msg.sender;
        FundFactory fundFactory = new FundFactory(deployer);
        (address priceFeed, , , ) = helperConfig.deployConfig(); //this returns the config which is a struct
        uint256 minDonationUsd = 1;
        uint256 campaignDurationInHours = 24;
        vm.startBroadcast();
        MockPoolToken poolToken = new MockPoolToken();
        address prizePool = address(poolToken);
        MockPrizeVault prizeVault = new MockPrizeVault(IERC20(prizePool));
        address swapContract = address(0x123);
        CrowdFund crowdfund = new CrowdFund(
            deployer,
            priceFeed,
            minDonationUsd,
            campaignDurationInHours,
            address(fundFactory),
            address(prizeVault),
            prizePool,
            swapContract
        );
        vm.stopBroadcast();
        return (
            deployer,
            crowdfund,
            address(fundFactory),
            poolToken,
            prizeVault
        );
    }
}
