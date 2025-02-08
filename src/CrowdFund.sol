// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {PrizeVault} from "pt-v5-vault/src/PrizeVault.sol";
import {PrizePool} from "pt-v5-prize-pool/src/PrizePool.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {FundFactory} from "./FundFactory.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "forge-std/console.sol";

/**
 * @title A crowd funding contract that supports prize savings.
 * @author Tunde Oduguwa
 * @dev Implements Uniswap V3 and Pool Together V5
 */

contract CrowdFund is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Error messages
    error CrowdFund__NotOwner(); //a custom gas saving error
    error CrowdFund__ExceedsMaxDonation();
    error CrowdFund__NotOptedInToPrizeSavings();
    error CrowdFund__InvalidPriceFeedData();
    error CrowdFund__DonationPeriodHasEnded();
    error CrowdFund__AmountLessThanMinimumDonationValue();
    error CrowdFund__SwapFailed();
    error CrowdFund__TokenAmountMustBeGreaterThanZero();
    error CrowdFund__InsufficientTokenAllowance();
    error CrowdFund__ExcessiveSlippage();
    error CrowdFund__NoPrizeDeposit();
    error CrowdFund__InsufficientPrizeVaultTokenDeposit();
    error CrowdFund__InsufficientPrizeVaultShares();
    error CrowdFund__InsufficientPrizeTokens();

    // State variables
    address public immutable i_owner;
    mapping(address => uint256) public s_donorAmount;
    mapping(address => uint256) public s_donorAddressToWETH;
    bool private s_donationsWithdrawn = false;
    bool private s_hasPrizeDeposit = false;
    bool private s_isFromPrizePool = false;
    bool private s_isFromPrizeVault = false;
    bool public s_isOptedInForPrizeSavings = false;
    uint256 private MIN_DONATION_USD;
    uint256 private s_fees = 0;
    uint256 public s_campaignEndTime; // Timestamp when the campaign ends
    uint256 private s_totalDepositsToPrizeVaultTokens = 0;
    uint256 private s_totalDepositsToPrizeVaultEth = 0;
    uint256 private s_sharesReceived = 0; //the donation as a proportion of the total amount in the vault
    uint256 private s_totalWinnings = 0;
    address public WETH9;
    address public UNISWAP_FACTORY;

    AggregatorV3Interface public s_dataFeed;
    FundFactory public immutable i_fundFactory;
    PrizeVault public s_prizeVault;
    PrizePool public s_prizePool;
    ISwapRouter public s_swapContract;

    constructor(address _owner, address _fundFactory) {
        i_owner = _owner;
        i_fundFactory = FundFactory(payable(_fundFactory));
    }

    event WETHUnwrap(uint256 value);

    function minDonationValueToEth() public view returns (uint256) {
        uint256 price = uint256(_ethToUsd());
        if (price <= 0) revert CrowdFund__InvalidPriceFeedData();
        uint8 decimals = s_dataFeed.decimals();
        uint256 ethValue = (MIN_DONATION_USD * 10 ** 18) / uint256(price);
        return ethValue * (10 ** decimals);
    }

    function _ethToUsd() internal view returns (int256) {
        (, int answer, , , ) = s_dataFeed.latestRoundData();
        return answer;
    }

    function prizeSavingsOptInStatus(bool _status) public onlyOwner {
        s_isOptedInForPrizeSavings = _status;
    }

    function setSwapContract(address _swapContract) public onlyOwner {
        s_swapContract = ISwapRouter(_swapContract);
    }

    function setWETH9(address _weth9) public onlyOwner {
        WETH9 = _weth9;
    }

    function setMinimumDonationAmount(uint256 _minDonation) public onlyOwner {
        MIN_DONATION_USD = _minDonation;
    }

    function setPriceFeed(address _priceFeed) public onlyOwner {
        s_dataFeed = AggregatorV3Interface(_priceFeed);
    }

    function setCampignDuration(uint256 _durationInHours) public onlyOwner {
        s_campaignEndTime = block.timestamp + (_durationInHours * 3600);
    }

    function setPrizeVault(address _prizeVault) public onlyOwner {
        s_prizeVault = PrizeVault(_prizeVault);
    }

    function setPrizePool(address _prizePool) public onlyOwner {
        s_prizePool = PrizePool(_prizePool);
    }

    function setUniswapV3FactoryAddress(
        address _uniswapV3Factory
    ) public onlyOwner {
        // Set the Uniswap V3 factory address
        UNISWAP_FACTORY = _uniswapV3Factory;
    }

    function acceptDonation(uint256 _minimumAmountOut) public payable {
        uint256 maxDonation = 100 ether;
        require(
            msg.sender != address(s_swapContract),
            "This is a swap operation and not a donation"
        );
        if (block.timestamp > s_campaignEndTime)
            revert CrowdFund__DonationPeriodHasEnded();
        if (msg.value < minDonationValueToEth())
            revert CrowdFund__AmountLessThanMinimumDonationValue();
        if (msg.value > maxDonation) revert CrowdFund__ExceedsMaxDonation();

        //wrap the eth to weth
        if (msg.value > 0) {
            s_donorAmount[msg.sender] += msg.value;
            s_donorAddressToWETH[msg.sender] = msg.value;
            //wrap ETH to WETH
            _wrapEth(msg.value);
        }

        s_donationsWithdrawn = false;

        if (!s_isOptedInForPrizeSavings)
            revert CrowdFund__NotOptedInToPrizeSavings();

        //swap WETH to USDC
        uint256 tokenEquivalent = _swapEthToUnderlyingAsset(
            s_donorAddressToWETH[msg.sender],
            _minimumAmountOut
        );
        if (tokenEquivalent < 0) revert CrowdFund__SwapFailed();
        depositToPrizeVault(tokenEquivalent);
        updateETHDepositToPrizeVault(s_donorAddressToWETH[msg.sender]);
    }

    function _getPairPoolAddressAndFee()
        internal
        view
        returns (uint16, address)
    {
        /**
            Rather than hardcoding a single fee tier, we will check incase the
            hardcoded fee does not exist for the pool, we check for the next
         */
        uint16[3] memory feeTiers = [500, 3000, 10000]; // 0.05%, 0.3%, 1%
        address lowestFeePool = address(0);
        uint16 lowestFee = type(uint16).max;
        address token0 = WETH9;
        address token1 = s_prizeVault.asset(); // USDC
        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAP_FACTORY);
        for (uint i = 0; i < 3; i++) {
            uint16 currentFee = feeTiers[i];
            address poolAddress = factory.getPool(token0, token1, currentFee);

            // If a pool exists for this fee tier and has a lower fee, update
            if (poolAddress != address(0)) {
                if (currentFee < lowestFee) {
                    lowestFeePool = poolAddress;
                    lowestFee = currentFee;
                }
            }
        }
        return (lowestFee, lowestFeePool);
    }

    function _estimateMinimumSwapOutputToken(
        uint256 _amount
    ) internal view returns (uint256 minimumAmountOut) {
        uint32 secondsAgo = 5;
        (, address pairPool) = _getPairPoolAddressAndFee();
        (int24 tick, ) = OracleLibrary.consult(pairPool, secondsAgo);
        minimumAmountOut = OracleLibrary.getQuoteAtTick(
            tick,
            uint128(_amount),
            WETH9,
            s_prizeVault.asset()
        );

        return minimumAmountOut;
    }

    function _estimateMinimumSwapOutputEth(
        uint256 _amount
    ) internal view returns (uint256 minimumAmountOut) {
        uint32 secondsAgo = 5;
        (, address pairPool) = _getPairPoolAddressAndFee();
        (int24 tick, ) = OracleLibrary.consult(pairPool, secondsAgo);
        minimumAmountOut = OracleLibrary.getQuoteAtTick(
            tick,
            uint128(_amount),
            s_prizeVault.asset(),
            WETH9
        );

        return minimumAmountOut;
    }

    function _swapEthToUnderlyingAsset(
        uint256 _amount,
        uint256 _minimumAmountOut
    ) internal returns (uint256) {
        // Swap ETH to the prize vault's underlying asset
        IERC20 underlyingToken = IERC20(s_prizeVault.asset());
        (uint24 poolFee, ) = _getPairPoolAddressAndFee(); //  lowest fee
        //uint256 amountOutMinimum = _estimateMinimumSwapOutputToken(_amount);
        TransferHelper.safeApprove(WETH9, address(s_swapContract), _amount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: address(underlyingToken),
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 15, // 15 seconds from now
                amountIn: _amount,
                amountOutMinimum: _minimumAmountOut,
                sqrtPriceLimitX96: 0
            });
        uint256 amountOut = s_swapContract.exactInputSingle(params);
        return amountOut;
    }

    function _swapUnderlyingAssetToEth(
        uint256 _amount,
        address _underlyingToken,
        uint256 _minimumAmountOut
    ) internal returns (uint256) {
        // Swap the prize vault's underlying asset to ETH
        address underlyingToken = _underlyingToken;
        (uint24 poolFee, ) = _getPairPoolAddressAndFee(); //  lowest fee
        //uint256 amountOutMinimum = _estimateMinimumSwapOutputEth(_amount); //- this will be calculated offchain
        TransferHelper.safeApprove(
            underlyingToken,
            address(s_swapContract),
            _amount
        );
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: underlyingToken,
                tokenOut: WETH9,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 15, // 15 seconds from now
                amountIn: _amount,
                amountOutMinimum: _minimumAmountOut,
                sqrtPriceLimitX96: 0
            });
        uint256 amountOut = s_swapContract.exactInputSingle(params);
        return amountOut;
    }

    function updateETHDepositToPrizeVault(uint256 _amount) public onlyOwner {
        s_totalDepositsToPrizeVaultEth += _amount;
    }

    /**
        The project owner can call this function manually or it is automated with every deposit by opt-in status
    */
    function depositToPrizeVault(uint256 _tokenAmount) public onlyOwner {
        // Get underlying token
        IERC20 underlyingToken = IERC20(s_prizeVault.asset());
        if (_tokenAmount <= 0)
            revert CrowdFund__TokenAmountMustBeGreaterThanZero();

        //asset returns the address of the underlying erc20 token
        underlyingToken.approve(address(s_prizeVault), _tokenAmount);
        uint256 allowance = underlyingToken.allowance(
            address(this),
            address(s_prizeVault)
        );
        if (allowance < _tokenAmount)
            revert CrowdFund__InsufficientTokenAllowance();

        // Calculate minimum shares we should receive (e.g., 0.5% slippage)
        uint256 expectedShares = s_prizeVault.convertToShares(_tokenAmount);
        uint256 minShares = (expectedShares * 995) / 1000;

        // Deposit and verify received shares
        uint256 sharesReceived = s_prizeVault.deposit(
            _tokenAmount,
            address(this)
        );
        if (sharesReceived < minShares) revert CrowdFund__ExcessiveSlippage();

        // Update state
        s_sharesReceived += sharesReceived;
        s_totalDepositsToPrizeVaultTokens += _tokenAmount; //token amounts
        s_hasPrizeDeposit = true;
    }

    function withdrawDepositFromPrizeVault(
        uint256 _tokenAmount,
        uint256 _minAmountOut
    ) public onlyOwner returns (uint256) {
        if (!s_hasPrizeDeposit) revert CrowdFund__NoPrizeDeposit();
        uint256 assetsToWithdraw = _tokenAmount == 0
            ? s_totalDepositsToPrizeVaultTokens
            : _tokenAmount;
        if (assetsToWithdraw > s_totalDepositsToPrizeVaultTokens)
            revert CrowdFund__InsufficientPrizeVaultTokenDeposit();

        // Calculate shares to burn for the requested assets
        uint256 sharesToBurn = s_prizeVault.convertToShares(assetsToWithdraw);
        if (sharesToBurn > s_sharesReceived)
            revert CrowdFund__InsufficientPrizeVaultShares();

        // Update state
        s_sharesReceived -= sharesToBurn;
        s_isFromPrizeVault = true;

        // Update deposit state if all funds withdrawn
        if (s_totalDepositsToPrizeVaultTokens == 0) {
            s_hasPrizeDeposit = false;
        }

        // Withdraw assets and burn shares
        uint256 withdrawnAmount = s_prizeVault.withdraw(
            assetsToWithdraw,
            address(this), // receiver of assets
            address(this) // owner of shares
        );

        if (withdrawnAmount < assetsToWithdraw)
            revert CrowdFund__ExcessiveSlippage();

        s_totalDepositsToPrizeVaultTokens -= withdrawnAmount;

        //swap the withdrawn amount USDC to the donation token (WETH)
        uint256 wethAmount = _swapUnderlyingAssetToEth(
            withdrawnAmount,
            s_prizeVault.asset(),
            _minAmountOut
        );

        if (wethAmount <= 0) revert CrowdFund__SwapFailed();
        //convert WETH to ETH
        IWETH(WETH9).withdraw(wethAmount);

        return wethAmount;
    }

    function _wrapEth(uint256 amount) internal {
        if (amount == 0) revert CrowdFund__TokenAmountMustBeGreaterThanZero();
        IWETH(WETH9).deposit{value: amount}();
    }

    function getWiningsBalance() public view returns (uint256) {
        IERC20 poolToken = s_prizePool.prizeToken();
        return poolToken.balanceOf(address(this));
    }

    /**
        This withdraws the winnings from the prize pool
    */

    function withdrawPrizeTokens(
        uint256 _tokenAmount,
        uint256 _minAmountOut
    ) public onlyOwner {
        IERC20 poolToken = s_prizePool.prizeToken();
        if (poolToken.balanceOf(address(this)) < _tokenAmount)
            revert CrowdFund__InsufficientPrizeTokens();
        uint256 amountToWithdraw = _tokenAmount == 0
            ? IERC20(poolToken).balanceOf(address(this))
            : _tokenAmount;
        //winning split
        uint256 platformWinningPercentage = 40;
        uint256 platformWinningPortion = (amountToWithdraw *
            platformWinningPercentage) / 100;
        uint256 projectOwnerWinningPortion = amountToWithdraw -
            platformWinningPortion;

        //approve transfer of tokens to the factory contract and the project owner
        IERC20(poolToken).approve(
            address(i_fundFactory),
            platformWinningPortion
        );

        require(
            IERC20(poolToken).transfer(
                address(i_fundFactory),
                platformWinningPortion
            ),
            "Token transfer failed to platform"
        );

        //update state
        s_isFromPrizePool = true;
        //convert projectOwnerWinningPortion USDC TO WETH
        uint256 ethWinnings = _swapUnderlyingAssetToEth(
            projectOwnerWinningPortion,
            address(poolToken),
            _minAmountOut
        );
        if (ethWinnings <= 0) revert CrowdFund__SwapFailed();

        //convert WETH to ETH
        IWETH(WETH9).withdraw(ethWinnings);

        //send to the project owner
        (bool success, ) = payable(i_owner).call{value: ethWinnings}("");
        require(success, "ETH winnings transfer failed");
    }

    function _handleWinnings(uint256 _winningsAmountInEth) internal {
        s_totalWinnings += _winningsAmountInEth;
        // Additional logic for winnings, e.g., distribution or recording
    }

    function _handleDepositReturn(uint256 _depositAmountInEth) internal {
        s_totalDepositsToPrizeVaultEth -= _depositAmountInEth;
        // Additional logic for handling the return of the original deposit
    }

    function _handleSwappedEth(uint256 _amount) internal {
        // Determine if the swapped ETH is winnings or original deposit
        if (s_isFromPrizePool) {
            // Handle as winnings
            _handleWinnings(_amount);
        } else if (s_isFromPrizeVault) {
            // Handle as original deposit
            _handleDepositReturn(_amount);
        }
    }

    function withdrawDonations(
        uint256 _amount, //eth
        uint256 _minAmountOut
    ) public onlyOwner {
        uint256 totalFunds = totalDonations();
        uint256 ethDepositWithdrawalAmount;
        if (s_hasPrizeDeposit) {
            if (s_totalDepositsToPrizeVaultTokens > 0) {
                uint256 tokenAmount = (_amount * s_sharesReceived) / 1 ether;
                ethDepositWithdrawalAmount = withdrawDepositFromPrizeVault(
                    tokenAmount,
                    _minAmountOut
                );
                require(
                    ethDepositWithdrawalAmount >= ((_amount * 98) / 100),
                    "Prize deposit withdrawal and swap failed or too low amount"
                );
            }
        } else {
            require(totalFunds >= _amount, "No funds available for withdrawal");
        }

        uint256 amountToWithdraw = _amount == 0
            ? totalFunds
            : ethDepositWithdrawalAmount;
        // Deduct platform fees
        uint8 reducedFeePercentage = 3;
        uint256 feePercentage = s_totalWinnings > 0
            ? reducedFeePercentage
            : getFeePercentage();
        uint256 platformFees = (amountToWithdraw * feePercentage) / 100;
        uint256 netFunds = amountToWithdraw - platformFees;
        s_fees += platformFees;
        s_totalDepositsToPrizeVaultEth -= amountToWithdraw;
        //s_totalWinnings = 0;

        //send to the project owner
        (bool feeSuccess, ) = payable(address(i_fundFactory)).call{
            value: platformFees
        }("");
        require(feeSuccess, "Fee transfer failed");

        //send to the project owner
        s_donationsWithdrawn = (amountToWithdraw == totalFunds);
        (bool success, ) = payable(i_owner).call{value: netFunds}("");
        require(success, "Withrawal failed!");
    }

    function totalDonations() public view returns (uint256) {
        return address(this).balance;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner && msg.sender != address(this)) {
            revert CrowdFund__NotOwner();
        }
        _;
    }

    receive() external payable {
        uint256 selfTrigger = 0;
        if (msg.sender == address(this)) {
            selfTrigger += msg.value;
        } else if (msg.sender == WETH9) {
            _handleSwappedEth(msg.value);
            emit WETHUnwrap(msg.value);
        } else {
            acceptDonation(0);
        }
    }

    fallback() external payable {
        uint256 selfTrigger = 0;
        if (msg.sender == address(this)) {
            selfTrigger += msg.value;
        } else if (msg.sender == WETH9) {
            _handleSwappedEth(msg.value);
            emit WETHUnwrap(msg.value);
        } else {
            acceptDonation(0);
        }
    }

    /**
        View / Pure functions Getter functions
     */

    function getDonorAmount(
        address _donor
    ) external view onlyOwner returns (uint256) {
        return s_donorAmount[_donor];
    }

    function getDonationState() external view returns (bool) {
        return s_donationsWithdrawn;
    }

    function getMinimumDonation() external view returns (uint256) {
        return MIN_DONATION_USD;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getEthToUsd() external view returns (int256) {
        return _ethToUsd();
    }

    function getDataFeedDecimals() external view returns (uint8) {
        return s_dataFeed.decimals();
    }

    function getMaxDonation() external pure returns (uint256) {
        return 100 ether;
    }

    function getFeePercentage() public pure returns (uint8) {
        return 5;
    }

    function getPlatfromWinningPercentage() external pure returns (uint8) {
        return 40;
    }

    function getSharesReceived() external view returns (uint256) {
        return s_sharesReceived;
    }

    function getWinningsReceived() external view returns (uint256) {
        return s_totalWinnings;
    }

    function getIsFromPrizePool() external view returns (bool) {
        return s_isFromPrizePool;
    }

    function getPrizeDepositState() external view returns (bool) {
        return s_hasPrizeDeposit;
    }

    function getTotalTokenDepositsToPrizeVault()
        external
        view
        returns (uint256)
    {
        return s_totalDepositsToPrizeVaultTokens;
    }

    function getTotalEthDepositsToPrizeVault() external view returns (uint256) {
        return s_totalDepositsToPrizeVaultEth;
    }
}
