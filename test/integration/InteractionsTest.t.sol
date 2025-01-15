// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ExternalContractA} from "../../script/Interactions.s.sol";
import {DeployCrowdFund} from "../../script/DeployCrowdFund.s.sol";
import {CrowdFund} from "../../src/CrowdFund.sol";

contract InteractionsTest is Test {
    CrowdFund crowdFund;
    address deployer;

    function setUp() external {
        DeployCrowdFund deployCrowdFundInstance = new DeployCrowdFund();
        (deployer, crowdFund, , , ) = deployCrowdFundInstance.run();
    }

    function testExternalContractCanFund() public {
        ExternalContractA externalContract = new ExternalContractA();
        externalContract.fundCrowdFund(address(crowdFund));

        uint256 totalDonations = crowdFund.totalDonations();
        address owner = crowdFund.getOwner();
        vm.prank(owner);
        address donor = crowdFund.getDonorAtIndex(0);

        assertGe(totalDonations, externalContract.getFundAmount());
        assertEq(donor, msg.sender);
    }

    function testExternalContractCanSendEther() public {
        ExternalContractA externalContract = new ExternalContractA();
        externalContract.sendEthToCrowdFund(address(crowdFund));

        uint256 totalDonations = crowdFund.totalDonations();
        address owner = crowdFund.getOwner();
        vm.prank(owner);
        address donor = crowdFund.getDonorAtIndex(0);

        assertGe(totalDonations, externalContract.getFundAmount());
        assertEq(donor, msg.sender);
    }

    // function testExternalContractCanWithdraw() public {
    //     ExternalContractA externalContract = new ExternalContractA();
    //     externalContract.fundCrowdFund(address(crowdFund));

    //     uint256 amountDonated = 0.01 ether;

    //     address owner = crowdFund.getOwner();

    //     console.log("Owner: ", owner);
    //     console.log("this: ", address(this));
    //     console.log("crowdFund: ", address(crowdFund));

    //     vm.prank(owner);

    //     externalContract.withdrawDonations(address(crowdFund), amountDonated);
    //     uint256 contractBalance = crowdFund.totalDonations();
    //     uint256 feesEarned = (amountDonated * 5) / 100;

    //     assertEq(0, contractBalance);
    //     assertEq(crowdFund.getDonationState(), true);
    //     assertGe(msg.sender.balance, amountDonated);
    //     assertEq(address(crowdFund.i_fundFactory()).balance, feesEarned);
    // }
}
