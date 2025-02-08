// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {CrowdFund} from "../../src/CrowdFund.sol";
import {DeployCrowdFund} from "../../script/DeployCrowdFund.s.sol";
import {FundFactory} from "../../src/FundFactory.sol";
import {PrizeVault} from "pt-v5-vault/src/PrizeVault.sol";
import {WETH} from "../mocks/MockWETH9.sol";
import {USDC} from "../mocks/MockUSDC.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {console} from "forge-std/console.sol";

contract CrowdFundTest is Test {
    error CrowdFund__NotOwner(); //a custom gas saving error
    error CrowdFund__ExceedsMaxDonation();
    error CrowdFund__DonationPeriodHasEnded();
    error CrowdFund__AmountLessThanMinimumDonationValue();
    address deployer;
    CrowdFund crowdFund;
    address fundFactory;
    address prizeVault;
    address priceFeed;
    address weth;
    address usdc;
    address uniswapV3factory;
    address prizePool;
    address swapContract;
    address poolPair;

    uint256 gasFeeAllowance = 1 ether;

    event FundsReceived(address _from, uint256 _amount);

    function setUp() external {
        DeployCrowdFund deployCrowdFundInstance = new DeployCrowdFund();
        (
            deployer,
            crowdFund,
            fundFactory,
            prizeVault,
            priceFeed,
            weth,
            usdc,
            uniswapV3factory,
            prizePool,
            swapContract,
            poolPair
        ) = deployCrowdFundInstance.run();

        crowdFund.prizeSavingsOptInStatus(true);
        crowdFund.setSwapContract(swapContract);
        crowdFund.setWETH9(weth);
        crowdFund.setMinimumDonationAmount(5);
        crowdFund.setPriceFeed(priceFeed);
        crowdFund.setCampignDuration(10);
        crowdFund.setPrizeVault(prizeVault);
        crowdFund.setPrizePool(prizePool);
        crowdFund.setUniswapV3FactoryAddress(uniswapV3factory);

        /**
            Necessary to mint weth for setting up initial observations
         */
        WETH(payable(weth)).mint(address(this), 10 ether);

        //add some eth to the crowdfund contract to pay for gas fees
        vm.deal(address(crowdFund), gasFeeAllowance);
        vm.deal(address(this), gasFeeAllowance);

        //add observations to the pool
        IUniswapV3Pool pool = IUniswapV3Pool(poolPair);
        pool.increaseObservationCardinalityNext(50);

        ISwapRouter s_swapContract = ISwapRouter(swapContract);

        for (uint256 i = 0; i < 5; i++) {
            // Perform a minimal swap to trigger observations
            uint256 _amount = 1 ether;
            TransferHelper.safeApprove(weth, address(s_swapContract), _amount);
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: weth,
                    tokenOut: usdc,
                    fee: 3000,
                    recipient: address(this),
                    deadline: block.timestamp + 5, // 15 seconds from now
                    amountIn: _amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            s_swapContract.exactInputSingle(params);
            // Increase the block timestamp by 1 second (or desired interval)
            vm.warp(block.timestamp + 5);
        }
    }

    function testOpeningBalances() public view {
        assertEq(IERC20(usdc).balanceOf(prizeVault), 0);
        assertEq(IERC20(weth).balanceOf(address(crowdFund)), 0);
        assertEq(address(crowdFund).balance, gasFeeAllowance);
    }

    function testMinDonationValueInUsd() public view {
        uint256 minDonationUsd = 5;
        uint256 minDonationValue = crowdFund.getMinimumDonation();
        assertEq(minDonationValue, minDonationUsd);
    }

    function testAcceptDonation() public payable {
        uint256 donationAmountEth = 5 ether;
        vm.deal(address(this), donationAmountEth);
        address owner = crowdFund.getOwner();
        vm.prank(owner);
        crowdFund.acceptDonation{value: donationAmountEth}(0);

        assertEq(crowdFund.getDonorAmount(address(this)), donationAmountEth);
        assertEq(IERC20(weth).balanceOf(address(crowdFund)), 0);
        assertEq(address(crowdFund).balance, gasFeeAllowance);
        assertEq(IERC20(usdc).balanceOf(address(crowdFund)), 0);
        assertFalse(crowdFund.getDonationState());
        assertEq(
            crowdFund.getTotalTokenDepositsToPrizeVault(),
            crowdFund.getSharesReceived()
        );
        assertEq(
            crowdFund.getTotalEthDepositsToPrizeVault(),
            donationAmountEth
        );
        assertTrue(crowdFund.getPrizeDepositState());
    }

    function testOwner() public view {
        address owner = crowdFund.getOwner();
        assertEq(owner, deployer); //msg.sender is the address that deployed this CrowdFundTest contract
    }

    function testMinDonationValueInEth() public view {
        uint256 minDonationUsd = 5;
        uint256 minDonationValueEth = crowdFund.minDonationValueToEth();
        uint256 currentEthPrice = uint256(crowdFund.getEthToUsd());
        uint256 expectedMinDonationValueEth = ((minDonationUsd * 1e18) /
            currentEthPrice) * (10 ** crowdFund.getDataFeedDecimals()); // 5 USD to ETH
        assertGe(minDonationValueEth, expectedMinDonationValueEth);
    }

    function testMultipleDonations() public {
        uint256 firstDonation = 0.02 ether;
        uint256 secondDonation = 0.03 ether;

        crowdFund.acceptDonation{value: firstDonation}(0);
        crowdFund.acceptDonation{value: secondDonation}(0);

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
        vm.expectRevert(CrowdFund__AmountLessThanMinimumDonationValue.selector);
        crowdFund.acceptDonation{value: belowMinDonation}(0);
    }

    function testRejectNoDonation() public {
        // Expect the transaction to revert
        vm.expectRevert(CrowdFund__AmountLessThanMinimumDonationValue.selector);
        crowdFund.acceptDonation(0);
    }

    function testRejectExcessiveDonation() public {
        uint256 excessiveDonation = 101 ether; // Exceeds maximum
        vm.expectRevert(CrowdFund__ExceedsMaxDonation.selector);
        vm.deal(address(this), excessiveDonation);
        crowdFund.acceptDonation{value: excessiveDonation}(0);
    }

    function testLargeDonation() public {
        uint256 largeDonation = type(uint256).max; // Maximum uint256 value
        vm.deal(address(this), largeDonation);
        vm.expectRevert();
        crowdFund.acceptDonation{value: largeDonation}(0);
    }

    function testWithdrawDonations() public {
        uint256 donationAmount = 1 ether;
        uint256 withdrawalAmount = 0.5 ether;
        uint256 feePercentage = crowdFund.getFeePercentage();

        vm.deal(address(this), donationAmount);
        crowdFund.acceptDonation{value: donationAmount}(0);
        address owner = crowdFund.getOwner();
        vm.prank(owner);
        crowdFund.withdrawDonations(withdrawalAmount, 0);
        assertGe(
            address(this).balance,
            (((withdrawalAmount * (100 - feePercentage)) / 100) * 99) / 100
        );

        //assertGe(crowdFund.getTotalEthDepositsToPrizeVault(), withdrawalAmount); //to be fixed
        assertTrue(crowdFund.getPrizeDepositState());
        assertFalse(crowdFund.getDonationState());
    }

    function testRejectWithdrawAsNonOwner() public {
        // Simulate a donation
        uint256 minDonation = crowdFund.minDonationValueToEth();
        crowdFund.acceptDonation{value: minDonation}(0);

        // Expect the transaction to revert when a non-owner tries to withdraw
        address nonOwner = address(0x123); // A random address
        vm.prank(nonOwner); // Set the next call to be from nonOwner
        vm.expectRevert(CrowdFund__NotOwner.selector);
        crowdFund.withdrawDonations(minDonation, 0);
    }

    function testReceive() public payable {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        // Send Ether directly to the contract using the receive function
        vm.deal(address(this), minDonation);
        (bool success, ) = payable(address(crowdFund)).call{value: minDonation}(
            ""
        );
        require(success, "Failed to send Ether");
        // Check the donor amount
        address owner = crowdFund.getOwner();
        // Check the donor amount
        vm.prank(owner);
        uint256 donation = crowdFund.getDonorAmount(address(this));

        assertEq(donation, minDonation);
        assertEq(IERC20(weth).balanceOf(address(crowdFund)), 0);
        assertEq(address(crowdFund).balance, gasFeeAllowance);
        assertEq(IERC20(usdc).balanceOf(address(crowdFund)), 0);
        assertFalse(crowdFund.getDonationState());
        assertEq(
            crowdFund.getTotalTokenDepositsToPrizeVault(),
            crowdFund.getSharesReceived()
        );
        assertEq(crowdFund.getTotalEthDepositsToPrizeVault(), minDonation);
        assertTrue(crowdFund.getPrizeDepositState());
    }

    function testFallback() public payable {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        // Send Ether with data to the contract using the fallback function
        vm.deal(address(this), minDonation);
        (bool success, ) = payable(address(crowdFund)).call{value: minDonation}(
            abi.encodeWithSignature("nonExistentFunction()")
        );
        require(success, "Failed to send Ether");

        // Check the donor amount
        address owner = crowdFund.getOwner();
        // Check the donor amount
        vm.prank(owner);
        uint256 donation = crowdFund.getDonorAmount(address(this));

        assertEq(donation, minDonation);
        assertEq(IERC20(weth).balanceOf(address(crowdFund)), 0);
        assertEq(address(crowdFund).balance, gasFeeAllowance);
        assertEq(IERC20(usdc).balanceOf(address(crowdFund)), 0);
        assertFalse(crowdFund.getDonationState());
        assertEq(
            crowdFund.getTotalTokenDepositsToPrizeVault(),
            crowdFund.getSharesReceived()
        );
        assertEq(crowdFund.getTotalEthDepositsToPrizeVault(), minDonation);
        assertTrue(crowdFund.getPrizeDepositState());
    }

    function testGetWinningsReceivedInitial() public view {
        uint256 winningsReceived = crowdFund.getWinningsReceived();
        assertEq(winningsReceived, 0);
    }

    function testWithdrawWinnings() public {
        uint256 winningsAmountUsdc = 25 ether; // 25 USDC
        vm.prank(prizePool);
        USDC(payable(usdc)).mint(address(crowdFund), winningsAmountUsdc); // Mint tokens to the contract

        address owner = crowdFund.getOwner();

        uint256 winningsReceived = IERC20(usdc).balanceOf(address(crowdFund));

        assertEq(winningsReceived, winningsAmountUsdc);

        vm.prank(owner);
        vm.deal(weth, 1 ether);
        crowdFund.withdrawPrizeTokens(winningsAmountUsdc, 0);

        assertEq(IERC20(usdc).balanceOf(address(crowdFund)), 0);
        assertEq(
            IERC20(usdc).balanceOf(address(fundFactory)),
            ((winningsAmountUsdc * 40) / 100)
        );
        assertTrue(
            crowdFund.getIsFromPrizePool(),
            "State should be updated to true"
        );
    }

    function testRejectDonationAfterCampaignEnd() public {
        uint256 minDonation = crowdFund.minDonationValueToEth();
        vm.warp(block.timestamp + 11 hours); // Warp time to 11 hours after campaign start
        vm.expectRevert(CrowdFund__DonationPeriodHasEnded.selector);
        crowdFund.acceptDonation{value: minDonation}(0);
    }

    // function testReceiveWinningsAfterCampaignEnd() public {
    //     uint256 tokenAmount = 22 ether;
    //     uint256 platformWinningPercentage = 40;
    //     uint256 platformWinningPortion = (tokenAmount *
    //         platformWinningPercentage) / 100;
    //     uint256 projectOwnerWinningPortion = tokenAmount -
    //         platformWinningPortion;

    //     address owner = crowdFund.getOwner();
    //     poolToken.mint(address(this), tokenAmount); // Mint tokens to the contract
    //     poolToken.approve(address(crowdFund), tokenAmount);
    //     vm.warp(block.timestamp + 25 hours);
    //     poolToken.transfer(address(crowdFund), tokenAmount); //this will simulate receiving winnings after the campaign has ended

    //     vm.startPrank(owner);
    //     poolToken.approve(fundFactory, platformWinningPortion);
    //     bool success = crowdFund.withdrawPrizeTokens(tokenAmount);
    //     vm.stopPrank();

    //     assertTrue(success, "Withdrawal should succeed");
    //     assertEq(
    //         projectOwnerWinningPortion,
    //         poolToken.balanceOf(address(crowdFund))
    //     );
    //     assertEq(
    //         platformWinningPortion,
    //         poolToken.balanceOf(address(fundFactory))
    //     );

    //     uint256 winningsInEth = 5 ether;
    //     // Simulate receiving winnings
    //     address swapContract = address(0x123); // the swap contract address
    //     vm.deal(swapContract, winningsInEth);
    //     vm.startPrank(swapContract);
    //     vm.warp(block.timestamp + 25 hours);
    //     (bool ethSendSuccess, ) = address(crowdFund).call{value: winningsInEth}(
    //         ""
    //     );
    //     require(ethSendSuccess, "Failed to send Ether");
    //     vm.stopPrank();

    //     uint256 winningsReceived = crowdFund.getWinningsReceived();
    //     assertEq(winningsReceived, winningsInEth);
    // }

    fallback() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}
