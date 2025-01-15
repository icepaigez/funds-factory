// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {IPrizeVault} from "./interfaces/IPrizeVault.sol";
import {IPrizePool} from "./interfaces/IPrizePool.sol";
import {FundFactory} from "./FundFactory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdFund {
    using SafeERC20 for IERC20;
    error CrowdFund__NotOwner(); //a custom gas saving error

    // State variables
    address public immutable i_owner;
    mapping(address => uint256) public s_donorAmount;
    address[] public s_donors;
    bool private s_donationsWithdrawn = false;
    bool private s_hasPrizeDeposit = false;
    bool private s_isFromPrizePool = false;
    bool private s_isFromPrizeVault = false;
    uint256 private MIN_DONATION_USD;
    uint256 private s_fees = 0;
    uint256 public immutable i_campaignEndTime; // Timestamp when the campaign ends
    uint256 private s_totalDepositsToPrizeVault = 0;
    uint256 private s_totalDepositsToPrizeVaultEth = 0;
    uint256 private s_sharesReceived = 0; //the donation as a proportion of the total amount in the vault
    uint256 private s_totalWinnings = 0;

    AggregatorV3Interface public immutable i_dataFeed;
    FundFactory public immutable i_fundFactory;
    IPrizeVault public immutable i_prizeVault;
    IPrizePool public immutable i_prizePool;
    address public immutable i_prizePoolAddress;
    address public immutable i_swapContract;

    constructor(
        address _owner,
        address _dataFeed,
        uint256 _minDonation,
        uint256 _campaignDurationInHours,
        address _fundFactory,
        address _prizeVault,
        address _prizePool,
        address _swapContract
    ) {
        i_owner = _owner;
        MIN_DONATION_USD = _minDonation;
        i_campaignEndTime = block.timestamp + (_campaignDurationInHours * 3600);
        i_dataFeed = AggregatorV3Interface(_dataFeed);
        i_fundFactory = FundFactory(payable(_fundFactory));
        i_prizeVault = IPrizeVault(_prizeVault);
        i_prizePool = IPrizePool(_prizePool);
        i_prizePoolAddress = _prizePool;
        i_swapContract = _swapContract;
    }

    event PrizeWithdrawn(
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );
    event FundsReceived(
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );

    function minDonationValueToEth() public view returns (uint256) {
        uint256 price = uint256(_ethToUsd());
        require(price > 0, "Invalid price feed data");
        uint8 decimals = i_dataFeed.decimals();
        uint256 ethValue = (MIN_DONATION_USD * 10 ** 18) / uint256(price);
        return ethValue * (10 ** decimals);
    }

    function _ethToUsd() internal view returns (int256) {
        (, int answer, , , ) = i_dataFeed.latestRoundData();
        return answer;
    }

    /**
        There will be an event emitted every time a donation is received. Once this event is emitted, if the project is opted in for prize savings, the donation will be converted to the prize vault's underlying asset and deposited to the prize vault. If the project is not opted in for prize savings, the donation will be held in the contract until the project owner withdraws it. Means that the project owner can now change the opt-in status of the project any time during the campaign as it is handled off-chain.
    */
    function acceptDonation() public payable {
        uint256 maxDonation = 100 ether;
        require(
            msg.sender != i_swapContract,
            "This is a swap operation and not a donation"
        );
        require(
            block.timestamp <= i_campaignEndTime,
            "Donations are no longer accepted"
        );
        require(
            msg.value >= minDonationValueToEth(),
            "You can only donate a $5 min equivalent in ETH!"
        );
        require(msg.value <= maxDonation, "Donation exceeds the maximum limit");
        s_donorAmount[msg.sender] += msg.value;
        s_donors.push(msg.sender);
        s_donationsWithdrawn = false;
        emit FundsReceived(msg.sender, msg.value, block.timestamp); //converted to prize vault's underlying asset and deposited to the prize vault off-chain
    }

    /**
        The project owner can call this function manually or it is automated with every deposit by opt-in status off-chain
    */
    function updateDepositToPrizeVault(uint256 _amount) public onlyOwner {
        s_totalDepositsToPrizeVaultEth += _amount;
    }

    /**
        The project owner can call this function manually or it is automated with every deposit by opt-in status off-chain
    */
    function depositToPrizeVault(uint256 _tokenAmount) public onlyOwner {
        // Get underlying token
        IERC20 underlyingToken = IERC20(i_prizeVault.asset());

        uint256 currentTotalFunds = underlyingToken.balanceOf(address(this));
        require(currentTotalFunds > 0, "No funds available for deposit");

        uint256 amountToDeposit = _tokenAmount == 0
            ? currentTotalFunds
            : _tokenAmount;
        require(currentTotalFunds >= amountToDeposit, "Insufficient funds");

        //asset returns the address of the underlying erc20 token
        underlyingToken.approve(address(i_prizeVault), amountToDeposit);

        // Calculate minimum shares we should receive (e.g., 0.5% slippage)
        uint256 expectedShares = i_prizeVault.convertToShares(amountToDeposit);
        uint256 minShares = (expectedShares * 995) / 1000;

        // Deposit and verify received shares
        uint256 sharesReceived = i_prizeVault.deposit(
            amountToDeposit,
            address(this)
        );
        require(sharesReceived >= minShares, "Excessive slippage");

        // Update state
        s_sharesReceived += sharesReceived;
        s_totalDepositsToPrizeVault += amountToDeposit; //0+20
        s_hasPrizeDeposit = true;
    }

    /**
        The project owner can call this function manually or it is automated with every deposit by opt-in when the contract is deployed. if called manually, _assetAmount here refers to the ETH amount the owner wants to withdraw but should be converted to the amount of pool tokens to be withdrawn from the prize vault, since the caller is not concerned about tokens and pools.

        This function should also emit an event when the withdrawal is successful; once this event is received, the swap function will be called off-chain to convert the pool tokens to the donation token (ETH, DAI, USDC, WBTC, etc.) 

        In the UI, there will be a conversion from the value entered by the user to the token equivalent as this function works with tokens and not the actual donation token (ETH, DAI, USDC, WBTC, etc.). The UI values will always be in terms of the donation token (ETH, DAI, USDC, WBTC, etc.)
    */

    function withdrawDepositFromPrizeVault(
        uint256 _tokenAmount
    ) public onlyOwner returns (bool) {
        require(s_hasPrizeDeposit, "No funds available for withdrawal");
        uint256 assetsToWithdraw = _tokenAmount == 0
            ? s_totalDepositsToPrizeVault
            : _tokenAmount;
        require(
            assetsToWithdraw <= s_totalDepositsToPrizeVault,
            "Insufficient funds"
        );

        // Calculate shares to burn for the requested assets
        uint256 sharesToBurn = i_prizeVault.convertToShares(assetsToWithdraw);
        require(sharesToBurn <= s_sharesReceived, "Insufficient shares");

        // Update state
        s_sharesReceived -= sharesToBurn;
        s_totalDepositsToPrizeVault -= assetsToWithdraw;
        s_isFromPrizeVault = true;

        // Update deposit state if all funds withdrawn
        if (s_totalDepositsToPrizeVault == 0) {
            s_hasPrizeDeposit = false;
        }

        // Withdraw assets and burn shares
        uint256 withdrawnAmount = i_prizeVault.withdraw(
            assetsToWithdraw,
            address(this), // receiver of assets
            address(this) // owner of shares
        );

        emit PrizeWithdrawn(
            address(i_prizeVault),
            withdrawnAmount,
            block.timestamp
        ); //this will trigger the swap function off-chain to convert the pool tokens to the donation token (ETH, DAI, USDC, WBTC, etc.)

        return true;
    }

    function getWiningsBalance() public view returns (uint256) {
        address poolToken = i_prizePool.prizeToken();
        return IERC20(poolToken).balanceOf(address(this));
    }

    /**
        if the project owner wants to withdraw the prize tokens rather than taking all the donations plus winnings converted to original donation token.
        once the event is emitted, the swap is done off-chain to convert the prize tokens to the donation token (ETH, DAI, USDC, WBTC, etc.)
    */
    function withdrawPrizeTokens(
        uint256 _tokenAmount
    ) public onlyOwner returns (bool) {
        address poolToken = i_prizePool.prizeToken();
        require(
            IERC20(poolToken).balanceOf(address(this)) >= _tokenAmount,
            "Insufficient prize tokens"
        );
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
        //convert projectOwnerWinningPortion back to donation token (e.g., ETH, DAI, USDC, WBTC, etc.)
        emit PrizeWithdrawn(
            address(i_prizePool),
            projectOwnerWinningPortion,
            block.timestamp
        );

        return true;
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

    function withdrawDonations(uint256 _amount) public onlyOwner {
        require(!s_donationsWithdrawn, "Funds have already been withdrawn");
        //check to see if there are any donations to the prize vault
        if (s_totalDepositsToPrizeVault > 0) {
            bool prizeDepositWithdrawalSuccess = withdrawDepositFromPrizeVault(
                0
            );
            require(
                prizeDepositWithdrawalSuccess,
                "Prize deposit withdrawal failed"
            );
        }

        if (s_totalWinnings > 0) {
            bool winningsWithdrawalSuccess = withdrawPrizeTokens(0);
            require(winningsWithdrawalSuccess, "Winnings withdrawal failed");
        }

        //at this point, all deposits and winnings have been taken back to the contract and converted to the original donation token
        uint256 totalFunds = totalDonations();
        require(totalFunds > 0, "No funds available for withdrawal");

        uint256 amountToWithdraw = _amount == 0 ? totalFunds : _amount;
        require(totalFunds >= amountToWithdraw, "Insufficient funds");

        // Deduct platform fees
        uint8 reducedFeePercentage = 3;
        uint256 feePercentage = s_totalWinnings > 0
            ? reducedFeePercentage
            : getFeePercentage();
        uint256 platformFees = (amountToWithdraw * feePercentage) / 100;
        uint256 netFunds = amountToWithdraw - platformFees;
        s_fees += platformFees;
        s_totalWinnings = 0;

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
        if (msg.sender != i_owner) {
            revert CrowdFund__NotOwner();
        }
        _;
    }

    receive() external payable {
        if (msg.sender == i_swapContract) {
            _handleSwappedEth(msg.value);
        } else {
            acceptDonation();
        }

        emit FundsReceived(msg.sender, msg.value, block.timestamp);
    }

    fallback() external payable {
        if (msg.sender == i_swapContract) {
            _handleSwappedEth(msg.value);
        } else {
            acceptDonation();
        }

        emit FundsReceived(msg.sender, msg.value, block.timestamp);
    }

    /**
        View / Pure functions Getter functions
     */

    function getDonorAmount(
        address _donor
    ) external view onlyOwner returns (uint256) {
        return s_donorAmount[_donor];
    }

    function getDonorCount() external view onlyOwner returns (uint256) {
        return s_donors.length;
    }

    function getDonorAtIndex(
        uint256 _index
    ) external view onlyOwner returns (address) {
        return s_donors[_index];
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
        return i_dataFeed.decimals();
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

    function getTotalDepositsToPrizeVault() external view returns (uint256) {
        return s_totalDepositsToPrizeVault;
    }
}
