// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {CrowdFund} from "../src/CrowdFund.sol";

/**
  Rather than testing the functions via the CLI, we use this script to run the tests automatically, by creating an external contract that interacts with the CrowdFund contract and tests functions within it.
 */
contract ExternalContractA is Script {
    uint256 private constant _FUND_AMOUNT = 0.01 ether;
    function run() public view returns (CrowdFund) {
        address mostRecent = DevOpsTools.get_most_recent_deployment(
            "CrowdFund",
            block.chainid
        );
        CrowdFund crowdFund = CrowdFund(payable(mostRecent));
        return crowdFund;
    }

    function fundCrowdFund(address _address) public {
        vm.startBroadcast();
        CrowdFund crowdFund = _address != address(0)
            ? CrowdFund(payable(_address))
            : run();
        crowdFund.acceptDonation{value: _FUND_AMOUNT}(0);
        console.log(
            "Funded CrowdFund from the external contract with:",
            _FUND_AMOUNT
        );
        vm.stopBroadcast();
    }

    function sendEthToCrowdFund(address _address) public {
        vm.startBroadcast();
        CrowdFund crowdFund = _address != address(0)
            ? CrowdFund(payable(_address))
            : run();
        (bool success, ) = address(crowdFund).call{value: _FUND_AMOUNT}("");
        console.log(
            "Sent ether to CrowdFund from the external contract with:",
            _FUND_AMOUNT
        );
        require(success, "Failed to send Ether");
        vm.stopBroadcast();
    }

    function withdrawDonations(
        address _address,
        uint256 _amount,
        uint256 _minAmountOut
    ) public {
        CrowdFund crowdFund = _address != address(0)
            ? CrowdFund(payable(_address))
            : run();
        crowdFund.withdrawDonations(_amount, _minAmountOut);
    }

    function getFundAmount() external pure returns (uint256) {
        return _FUND_AMOUNT;
    }
}
