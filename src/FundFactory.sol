// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CrowdFund} from "./CrowdFund.sol";

contract FundFactory {
    address[] public deployedFunds;
    uint256 public feesEarned = 0;
    mapping(address => bool) public startedFundRaising;
    mapping(address => uint256) public fundsRaised;
    address immutable i_owner;

    constructor(address _owner) {
        i_owner = _owner;
    }

    function createFund(
        uint256 _minDonationAmount,
        address _dataFeed,
        uint256 _campaignDurationInHours,
        address _fundFactory,
        address _prizeVault,
        address _prizePool,
        address _swapContract
    ) public returns (CrowdFund) {
        CrowdFund newFund = new CrowdFund(
            msg.sender,
            _dataFeed,
            _minDonationAmount,
            _campaignDurationInHours,
            _fundFactory,
            _prizeVault,
            _prizePool,
            _swapContract
        );
        deployedFunds.push(address(newFund));
        startedFundRaising[address(newFund)] = true;
        return newFund;
    }

    function getDeployedFunds()
        public
        view
        onlyOwner
        returns (address[] memory)
    {
        return deployedFunds;
    }

    function getTotalAmountRaised() public onlyOwner returns (uint256) {
        uint256 totalAmount = 0;
        uint256 deployedFundsCount = deployedFunds.length;
        for (uint256 i = 0; i < deployedFundsCount; i++) {
            totalAmount += CrowdFund(payable(deployedFunds[i]))
                .totalDonations();
            fundsRaised[deployedFunds[i]] = totalAmount;
        }
        return totalAmount;
    }

    function getDeployedFundsCount() public view returns (uint256) {
        return deployedFunds.length;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function withdrawEthEarnings() public onlyOwner {
        (bool success, ) = payable(i_owner).call{value: address(this).balance}(
            ""
        );
        require(success, "Withdrawal failed.");
    }

    fallback() external payable {
        require(startedFundRaising[msg.sender], "Operation not allowed");
        feesEarned += msg.value;
    }

    receive() external payable {
        require(startedFundRaising[msg.sender], "Operation not allowed");
        feesEarned += msg.value;
    }

    modifier onlyOwner() {
        require(msg.sender == i_owner, "Only owner can call this function");
        _;
    }
}
