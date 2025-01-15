// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundFactory} from "../src/FundFactory.sol";

contract DeployFundFactory is Script {
    function run() external returns (FundFactory) {
        FundFactory fundFactory;
        vm.startBroadcast();
        fundFactory = new FundFactory(msg.sender);
        vm.stopBroadcast();
        return fundFactory;
    }
}
