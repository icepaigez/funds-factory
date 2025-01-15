// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CrowdFund} from "../../src/CrowdFund.sol";
import {DeployCrowdFund} from "../../script/DeployCrowdFund.s.sol";
import {MockPoolToken} from "../mocks/MockPoolToken.sol";
import {FundFactory} from "../../src/FundFactory.sol";
import {MockPrizeVault} from "../mocks/MockPrizeVault.sol";

contract CrowdFundTest is Test {
    error CrowdFund__NotOwner(); //a custom gas saving error
    CrowdFund crowdFund;
    address fundFactory;
    MockPoolToken poolToken;
    MockPrizeVault prizeVault;
    address deployer;

    uint8 minDonationUsd = 1;

    function setUp() external {
        DeployCrowdFund deployCrowdFundInstance = new DeployCrowdFund();
        (
            deployer,
            crowdFund,
            fundFactory,
            poolToken,
            prizeVault
        ) = deployCrowdFundInstance.run();

        uint256 mintAmount = 35700000;
        poolToken.mint(address(this), mintAmount);

        // Approve the vault to spend tokens
        poolToken.approve(address(prizeVault), mintAmount);

        // Deposit tokens into the vault
        prizeVault.deposit(mintAmount, address(this));

        require(prizeVault.balanceOf(address(this)) > 0, "Deposit failed");
        require(
            poolToken.balanceOf(address(this)) == 0,
            "Token not transferred"
        );
    }

    function testMinDonationValueInUsd() public view {
        uint256 minDonationValue = crowdFund.getMinimumDonation();
        assertEq(minDonationValue, minDonationUsd);
    }

    function testOwner() public view {
        address owner = crowdFund.getOwner();
        assertEq(owner, deployer); //msg.sender is the address that deployed this CrowdFundTest contract
    }

    function testMinDonationValueInEth() public view {
        uint256 minDonationValueEth = crowdFund.minDonationValueToEth();
        uint256 currentEthPrice = uint256(crowdFund.getEthToUsd());
        uint256 expectedMinDonationValueEth = ((minDonationUsd * 1e18) /
            currentEthPrice) * (10 ** crowdFund.getDataFeedDecimals()); // 5 USD to ETH
        assertGe(minDonationValueEth, expectedMinDonationValueEth);
    }

    function testAcceptDonation() public payable {
        uint256 minDonation = crowdFund.minDonationValueToEth();

        // Simulate a donation
        crowdFund.acceptDonation{value: minDonation}(); // Call the function

        address owner = crowdFund.getOwner();
        // Check the donor amount
        vm.startPrank(owner);
        uint256 donation = crowdFund.getDonorAmount(address(this));
        address donor = crowdFund.getDonorAtIndex(0);
        vm.stopPrank();

        assertEq(donation, minDonation);
        assert(donation <= crowdFund.getMaxDonation());
        assertGe(crowdFund.totalDonations(), minDonation);
        assertEq(donor, address(this));
        assertEq(crowdFund.getDonationState(), false);
        assertEq(crowdFund.getSharesReceived(), 0);
        assertEq(crowdFund.getWinningsReceived(), 0);
    }

    function testMultipleDonations() public {
        uint256 firstDonation = 0.02 ether;
        uint256 secondDonation = 0.03 ether;

        crowdFund.acceptDonation{value: firstDonation}();
        crowdFund.acceptDonation{value: secondDonation}();

        address owner = crowdFund.getOwner();
        vm.prank(owner);

        assertEq(
            crowdFund.getDonorAmount(address(this)),
            firstDonation + secondDonation
        );
    }

    function testRejectLowDonation() public {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        uint256 belowMinDonation = (minDonation * 9) / 10; // 10% less than the minimum

        // Expect the transaction to revert
        vm.expectRevert("You can only donate a $5 min equivalent in ETH!");
        crowdFund.acceptDonation{value: belowMinDonation}();
    }

    function testRejectNoDonation() public {
        // Expect the transaction to revert
        vm.expectRevert("You can only donate a $5 min equivalent in ETH!");
        crowdFund.acceptDonation();
    }

    function testRejectExcessiveDonation() public {
        uint256 excessiveDonation = 200 ether; // Exceeds maximum
        vm.expectRevert("Donation exceeds the maximum limit");
        crowdFund.acceptDonation{value: excessiveDonation}();
    }

    function testLargeDonation() public {
        uint256 largeDonation = type(uint256).max; // Maximum uint256 value
        vm.deal(address(this), largeDonation);
        vm.expectRevert("Donation exceeds the maximum limit");
        crowdFund.acceptDonation{value: largeDonation}();
    }

    function testWithdrawDonations() public {
        address owner = crowdFund.getOwner();
        uint256 ethAmount = 22 ether;
        address swapContract = address(0x123); // the swap contract address

        crowdFund.acceptDonation{value: ethAmount}(); // Simulate a donation

        //simulate the donations converted to tokens, assuming 1:1 conversion of tokens to eth sent to the contract and then deposited in the prize vault
        uint256 tokenAmount = 22 ether;
        poolToken.mint(swapContract, tokenAmount); // Mint tokens to the contract
        vm.prank(address(crowdFund));
        (bool swapSuccess, ) = payable(swapContract).call{value: ethAmount}("");
        require(swapSuccess, "Failed to send Ether");

        assertEq(poolToken.balanceOf(swapContract), tokenAmount);
        assertEq(poolToken.balanceOf(address(crowdFund)), 0);
        assertEq(address(crowdFund).balance, 0);
        assertEq(swapContract.balance, ethAmount);

        //send the tokens from the swap contract to the crowdFund contract
        vm.prank(swapContract);
        poolToken.transfer(address(crowdFund), tokenAmount);
        assertEq(poolToken.balanceOf(address(crowdFund)), tokenAmount);
        assertEq(poolToken.balanceOf(swapContract), 0);
        assertEq(address(crowdFund).balance, 0);
        assertEq(swapContract.balance, ethAmount);

        //simulate deposit to the prize vault
        vm.prank(owner);
        crowdFund.depositToPrizeVault(tokenAmount);

        assertEq(poolToken.balanceOf(address(crowdFund)), 0);
        assertEq(prizeVault.balanceOf(address(crowdFund)), tokenAmount);
        assertEq(crowdFund.getTotalDepositsToPrizeVault(), tokenAmount);
        assertEq(crowdFund.getSharesReceived(), tokenAmount);

        //simulate a winning received
        uint256 winningTokenAmount = 4.2 ether;
        //send it to the crowdFund contract
        vm.prank(address(prizeVault));
        poolToken.transfer(address(crowdFund), winningTokenAmount);

        assertEq(poolToken.balanceOf(address(crowdFund)), winningTokenAmount);

        //simulate the withdrawal of the winnings
        uint256 platformWinningPercentage = 40;
        uint256 platformWinningPortion = (winningTokenAmount *
            platformWinningPercentage) / 100;
        uint256 projectOwnerWinningPortion = winningTokenAmount -
            platformWinningPortion;
        vm.prank(owner);
        crowdFund.withdrawPrizeTokens(winningTokenAmount);

        assertEq(
            poolToken.balanceOf(address(crowdFund)),
            projectOwnerWinningPortion
        );
        assertEq(
            poolToken.balanceOf(address(fundFactory)),
            platformWinningPortion
        );
        assertEq(prizeVault.balanceOf(address(crowdFund)), tokenAmount);
        assertTrue(crowdFund.getIsFromPrizePool(), "State should be updated");
    }

    function testWithdrawNoFunds(uint256 _amount) public {
        address owner = crowdFund.getOwner();
        vm.prank(owner);
        vm.expectRevert("No funds available for withdrawal");
        crowdFund.withdrawDonations(_amount);
    }

    function testWithdrawFromMultipleFunders() public {
        address owner = address(this);
        uint256 minDonation = crowdFund.minDonationValueToEth();

        // Simulate multiple donations
        uint160 numDonations = 10;

        for (uint160 i = 1; i <= numDonations; i++) {
            hoax(address(i), minDonation); // Set the next call to be from a different address linked to the donor index and fund the address with minDonation
            crowdFund.acceptDonation{value: minDonation}();
        }

        vm.expectRevert(
            "Fee transfer failed"
        ); /**
        this is because the fund was not created via the factory, so when the fee is sent, the factory rejects it as it does not have the address of the fund in its list of deployed funds 
        */

        // Owner withdraws donations
        vm.startPrank(owner); // Set the next call to be from the owner
        crowdFund.withdrawDonations(minDonation * numDonations);

        // Check if the owner's balance increased
        uint256 finalOwnerBalance = owner.balance;
        uint256 donorCount = crowdFund.getDonorCount();
        vm.stopPrank();

        uint256 contractBalance = crowdFund.totalDonations();
        // uint256 feesEarned = (minDonation *
        //     numDonations *
        //     crowdFund.getFeePercentage()) / 100;

        assertGe(finalOwnerBalance, minDonation * numDonations);
        assertEq(contractBalance, minDonation * numDonations);
        assertEq(crowdFund.getDonationState(), false);
        assertEq(donorCount, numDonations);
        assertEq(address(crowdFund.i_fundFactory()).balance, 0);
    }

    function testRejectWithdrawAsNonOwner() public {
        // Simulate a donation
        uint256 minDonation = crowdFund.minDonationValueToEth();
        crowdFund.acceptDonation{value: minDonation}();

        // Expect the transaction to revert when a non-owner tries to withdraw
        address nonOwner = address(0x123); // A random address
        vm.prank(nonOwner); // Set the next call to be from nonOwner
        vm.expectRevert(CrowdFund__NotOwner.selector);
        crowdFund.withdrawDonations(minDonation);
    }

    function testReceive() public payable {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        // Send Ether directly to the contract using the receive function
        (bool success, ) = payable(address(crowdFund)).call{value: minDonation}(
            ""
        );
        require(success, "Failed to send Ether");
        // Check the donor amount
        address owner = crowdFund.getOwner();
        // Check the donor amount
        vm.startPrank(owner);
        uint256 donation = crowdFund.getDonorAmount(address(this));
        address donor = crowdFund.getDonorAtIndex(0);
        vm.stopPrank();

        assertEq(donation, minDonation);
        assertEq(crowdFund.getDonationState(), false);
        assertEq(donor, address(this));
        assertGe(crowdFund.totalDonations(), minDonation);
    }

    function testFallback() public payable {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        // Send Ether with data to the contract using the fallback function
        (bool success, ) = payable(address(crowdFund)).call{
            value: minDonation,
            gas: 100000
        }(abi.encodeWithSignature("nonExistentFunction()"));
        require(success, "Failed to send Ether");

        // Check the donor amount
        address owner = crowdFund.getOwner();
        // Check the donor amount
        vm.startPrank(owner);
        uint256 donation = crowdFund.getDonorAmount(address(this));
        address donor = crowdFund.getDonorAtIndex(0);
        vm.stopPrank();

        assertEq(donation, minDonation);
        assertEq(crowdFund.getDonationState(), false);
        assertEq(donor, address(this));
        assertGe(crowdFund.totalDonations(), minDonation);
    }

    function testGetWinningsReceivedInitial() public view {
        uint256 winningsReceived = crowdFund.getWinningsReceived();
        assertEq(winningsReceived, 0);
    }

    function testGetWinningsReceivedAfterReceiving() public {
        uint256 tokenAmount = 22 ether;
        uint256 platformWinningPercentage = 40;
        uint256 platformWinningPortion = (tokenAmount *
            platformWinningPercentage) / 100;
        uint256 projectOwnerWinningPortion = tokenAmount -
            platformWinningPortion;

        address owner = crowdFund.getOwner();
        poolToken.mint(address(crowdFund), tokenAmount); // Mint tokens to the contract
        vm.startPrank(owner);
        poolToken.approve(fundFactory, platformWinningPortion);
        bool success = crowdFund.withdrawPrizeTokens(tokenAmount);
        vm.stopPrank();

        assertTrue(success, "Withdrawal should succeed");
        assertEq(
            projectOwnerWinningPortion,
            poolToken.balanceOf(address(crowdFund))
        );
        assertEq(
            platformWinningPortion,
            poolToken.balanceOf(address(fundFactory))
        );

        // Verify state update
        assertTrue(crowdFund.getIsFromPrizePool(), "State should be updated");

        uint256 winningsInEth = 5 ether;
        // Simulate receiving winnings
        address swapContract = address(0x123); // the swap contract address
        vm.deal(swapContract, winningsInEth);
        vm.startPrank(swapContract);
        (bool ethSendSuccess, ) = address(crowdFund).call{value: winningsInEth}(
            ""
        );
        require(ethSendSuccess, "Failed to send Ether");
        vm.stopPrank();

        uint256 winningsReceived = crowdFund.getWinningsReceived();
        assertEq(winningsReceived, winningsInEth);
    }

    function testDonationFromSwapContract() public {
        uint256 donation = 0.01 ether;
        address swapContract = address(0x123); // the swap contract address
        vm.deal(swapContract, donation);
        vm.prank(swapContract);
        vm.expectRevert("This is a swap operation and not a donation");
        crowdFund.acceptDonation{value: donation}();
    }

    function testDonationAfterCampaignEnd() public {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        vm.warp(block.timestamp + 25 hours); // Warp time to 25 hours after campaign start
        vm.expectRevert("Donations are no longer accepted");
        crowdFund.acceptDonation{value: minDonation}();
    }

    function testReceiveWinningsAfterCampaignEnd() public {
        uint256 tokenAmount = 22 ether;
        uint256 platformWinningPercentage = 40;
        uint256 platformWinningPortion = (tokenAmount *
            platformWinningPercentage) / 100;
        uint256 projectOwnerWinningPortion = tokenAmount -
            platformWinningPortion;

        address owner = crowdFund.getOwner();
        poolToken.mint(address(this), tokenAmount); // Mint tokens to the contract
        poolToken.approve(address(crowdFund), tokenAmount);
        vm.warp(block.timestamp + 25 hours);
        poolToken.transfer(address(crowdFund), tokenAmount); //this will simulate receiving winnings after the campaign has ended

        vm.startPrank(owner);
        poolToken.approve(fundFactory, platformWinningPortion);
        bool success = crowdFund.withdrawPrizeTokens(tokenAmount);
        vm.stopPrank();

        assertTrue(success, "Withdrawal should succeed");
        assertEq(
            projectOwnerWinningPortion,
            poolToken.balanceOf(address(crowdFund))
        );
        assertEq(
            platformWinningPortion,
            poolToken.balanceOf(address(fundFactory))
        );

        uint256 winningsInEth = 5 ether;
        // Simulate receiving winnings
        address swapContract = address(0x123); // the swap contract address
        vm.deal(swapContract, winningsInEth);
        vm.startPrank(swapContract);
        vm.warp(block.timestamp + 25 hours);
        (bool ethSendSuccess, ) = address(crowdFund).call{value: winningsInEth}(
            ""
        );
        require(ethSendSuccess, "Failed to send Ether");
        vm.stopPrank();

        uint256 winningsReceived = crowdFund.getWinningsReceived();
        assertEq(winningsReceived, winningsInEth);
    }

    function testDepositToPrizeVault() public {
        uint256 tokenAmount = 34 ether;
        poolToken.mint(address(crowdFund), tokenAmount); // Mint tokens to the contract
        poolToken.approve(address(prizeVault), tokenAmount);

        // Deposit tokens into the vault
        address owner = crowdFund.getOwner();
        vm.prank(owner);
        crowdFund.depositToPrizeVault(tokenAmount);

        assertEq(poolToken.balanceOf(address(crowdFund)), 0);
        assertTrue(crowdFund.getPrizeDepositState(), "Deposit failed");
        assertEq(prizeVault.balanceOf(address(crowdFund)), tokenAmount);
        assertEq(crowdFund.getTotalDepositsToPrizeVault(), tokenAmount);
        assert(crowdFund.getSharesReceived() == tokenAmount);
    }

    function testWithdrawSomeDepositFromPrizeVault() public {
        uint256 tokenAmount = 17 ether;
        poolToken.mint(address(crowdFund), tokenAmount); // Mint tokens to the contract
        poolToken.approve(address(prizeVault), tokenAmount);

        address owner = crowdFund.getOwner();
        vm.startPrank(owner);
        // Deposit tokens into the vault
        crowdFund.depositToPrizeVault(tokenAmount);

        // Withdraw tokens from the vault
        uint amountToWithdraw = 10 ether;
        crowdFund.withdrawDepositFromPrizeVault(amountToWithdraw);
        vm.stopPrank();

        assertEq(poolToken.balanceOf(address(crowdFund)), amountToWithdraw);
        assertEq(
            prizeVault.balanceOf(address(crowdFund)),
            tokenAmount - amountToWithdraw
        );
        assertTrue(crowdFund.getPrizeDepositState(), "Withdrawal failed");
        assertEq(
            crowdFund.getTotalDepositsToPrizeVault(),
            tokenAmount - amountToWithdraw
        );
        assertEq(crowdFund.getSharesReceived(), tokenAmount - amountToWithdraw);
    }

    function testWithdrawAllDepositsFromPrizeVault() public {
        uint256 tokenAmount = 17 ether;
        poolToken.mint(address(crowdFund), tokenAmount); // Mint tokens to the contract
        poolToken.approve(address(prizeVault), tokenAmount);

        address owner = crowdFund.getOwner();
        vm.startPrank(owner);
        // Deposit tokens into the vault
        crowdFund.depositToPrizeVault(tokenAmount);

        // Withdraw tokens from the vault
        crowdFund.withdrawDepositFromPrizeVault(tokenAmount);
        vm.stopPrank();

        assertEq(poolToken.balanceOf(address(crowdFund)), tokenAmount);
        assertEq(prizeVault.balanceOf(address(crowdFund)), 0);
        assertFalse(crowdFund.getPrizeDepositState(), "Withdrawal failed");
        assertEq(crowdFund.getTotalDepositsToPrizeVault(), 0);
        assertEq(crowdFund.getSharesReceived(), 0);
    }

    function testWithdrawAllDepositsFromPrizeVault2() public {
        uint256 tokenAmount = 17 ether;
        poolToken.mint(address(crowdFund), tokenAmount); // Mint tokens to the contract
        poolToken.approve(address(prizeVault), tokenAmount);

        address owner = crowdFund.getOwner();
        vm.startPrank(owner);
        // Deposit tokens into the vault
        crowdFund.depositToPrizeVault(tokenAmount);

        // Withdraw tokens from the vault
        crowdFund.withdrawDepositFromPrizeVault(0);
        vm.stopPrank();

        assertEq(poolToken.balanceOf(address(crowdFund)), tokenAmount);
        assertEq(prizeVault.balanceOf(address(crowdFund)), 0);
        assertFalse(crowdFund.getPrizeDepositState(), "Withdrawal failed");
        assertEq(crowdFund.getTotalDepositsToPrizeVault(), 0);
        assertEq(crowdFund.getSharesReceived(), 0);
    }
}
