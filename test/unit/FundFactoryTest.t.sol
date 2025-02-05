// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundFactory} from "../../src/FundFactory.sol";
import {CrowdFund} from "../../src/CrowdFund.sol";
import {DeployFundFactory} from "../../script/DeployFundFactory.s.sol";
//import {HelperConfig} from "../../script/HelperConfig.s.sol";

// contract FundFactoryTest is Test {
//     FundFactory fundFactory;

//     uint256 minDonationAmountUsd = 5;
//     address dataFeed;
//     uint256 campaignDurationInHours = 47;
//     address prizeVault = address(0x456);
//     address prizePool = address(0x789);
//     address swapContract = address(0xabc);
//     address deployer = address(0xdef);

//     function setUp() external {
//         DeployFundFactory deployFundFactoryInstance = new DeployFundFactory();
//         fundFactory = deployFundFactoryInstance.run();

//         HelperConfig helperConfig = new HelperConfig();
//         (address priceFeed, , , ) = helperConfig.deployConfig();
//         dataFeed = priceFeed;
//     }

//     function testCreateFund() public {
//         address fundFactoryAddress = address(fundFactory);
//         CrowdFund fund = fundFactory.createFund(
//             minDonationAmountUsd,
//             dataFeed,
//             campaignDurationInHours,
//             fundFactoryAddress,
//             prizeVault,
//             prizePool,
//             swapContract
//         );

//         address fundAddress = payable(address(fund));
//         uint256 feePercentage = 5;

//         assertEq(fundFactory.deployedFunds(0), fundAddress);
//         assertEq(fundFactory.getDeployedFundsCount(), 1);
//         assertEq(fundFactory.getTotalAmountRaised(), 0);
//         assertEq(fund.getFeePercentage(), feePercentage);

//         uint256 donationAmount = 10 ether;
//         address donor = address(0xdef);
//         vm.deal(donor, donationAmount);
//         vm.prank(donor);
//         fund.acceptDonation{value: donationAmount}();
//         assertEq(fundFactory.getTotalAmountRaised(), donationAmount);
//     }

//     function testCreateMultipleFunds() public {
//         uint256 numFunds = 15;
//         address fundFactoryAddress = address(fundFactory);
//         for (uint256 i = 0; i < numFunds; i++) {
//             CrowdFund fund = fundFactory.createFund(
//                 minDonationAmountUsd,
//                 dataFeed,
//                 campaignDurationInHours,
//                 fundFactoryAddress,
//                 prizeVault,
//                 prizePool,
//                 swapContract
//             );
//             address fundAddress = payable(address(fund));
//             assertEq(fundFactory.deployedFunds(i), fundAddress);
//         }

//         assertEq(fundFactory.getDeployedFundsCount(), numFunds);
//         assertEq(fundFactory.getTotalAmountRaised(), 0);
//         assertEq(
//             CrowdFund(payable(fundFactory.deployedFunds(4)))
//                 .getWinningsReceived(),
//             0
//         );
//     }

//     function testFallbackWithoutRaisingFunds() public {
//         uint256 amount = 1 ether;
//         address donor = address(0xdef);
//         vm.deal(donor, amount);

//         vm.expectRevert("Operation not allowed");
//         vm.prank(donor);
//         (bool success, ) = address(fundFactory).call{value: amount}("");
//         require(success, "Fallback failed");
//     }

//     function testFallbackAfterRaisingFunds() public {
//         uint256 amount = 1 ether;
//         address donor = address(0xdef);
//         vm.deal(donor, amount);

//         vm.startPrank(deployer);
//         CrowdFund fund = fundFactory.createFund(
//             minDonationAmountUsd,
//             dataFeed,
//             campaignDurationInHours,
//             address(fundFactory),
//             prizeVault,
//             prizePool,
//             swapContract
//         );
//         vm.stopPrank();

//         vm.prank(donor);
//         fund.acceptDonation{value: amount}();

//         uint256 feesEarned = (amount * 5) / 100;
//         assertEq(fundFactory.feesEarned(), 0);

//         //withdrawal
//         address owner = fund.getOwner();
//         console.log("owner: ", owner);
//         vm.prank(owner);
//         fund.withdrawDonations(amount);
//         assertEq(fundFactory.feesEarned(), feesEarned);
//     }
// }
