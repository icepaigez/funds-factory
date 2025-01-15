# Crowd Funding Platform

A decentralized crowdfunding platform built on Ethereum using Foundry.

## Overview

The CrowdFund project allows users to create and participate in crowdfunding campaigns. It provides a secure and transparent way for project creators to raise funds while allowing backers to support projects they believe in. The platform includes features for managing donations, tracking contributors, and ensuring that funds are only withdrawn after the campaign has ended.

## Features

- **Fund Creation**: Users can create crowdfunding campaigns with customizable parameters.
- **Minimum Donation Amount**: Set a minimum donation amount in USD (converted to ETH).
- **Real-Time ETH/USD Price Feed**: Integration with Chainlink for accurate price feeds.
- **Secure Fund Management**: Only the campaign owner can withdraw funds after the campaign ends.
- **Multiple Donor Tracking**: Keep track of individual donor contributions and total donations.
- **Donation State Management**: Manage the state of donations and ensure that no donations are accepted after the campaign ends.
- **No-loss lottery Integration**: Option to deposit donations into a no-loss lottery for potentially boosting the funds raised.
- **Fee Management**: The platform can earn fees from donations and prize winnings.

## Technical Stack

- **Solidity**: ^0.8.19
- **Foundry**: For testing and deployment.
- **Chainlink Price Feeds**: For real-time ETH/USD price data.
- **OpenZeppelin Contracts**: For secure token handling and access control.

## Contract Architecture

### Main Components

1. **FundFactory Contract**:

   - Manages the creation of `CrowdFund` contracts.
   - Tracks deployed funds and fees earned.
   - Provides functions to retrieve deployed funds and total amounts raised.

2. **CrowdFund Contract**:
   - Handles the crowdfunding logic, including accepting donations and managing prize vault deposits.
   - Tracks donor contributions and manages the state of the campaign.
   - Implements functions for the project owner to withdraw funds and manage prize tokens.

### Key Functions

- **FundFactory**:

  - `createFund(...)`: Creates a new `CrowdFund` contract.
  - `getDeployedFunds()`: Returns the list of deployed funds.
  - `getTotalAmountRaised()`: Calculates the total amount raised across all funds.
  - `withdrawEthEarnings()`: Allows the owner to withdraw earnings.

- **CrowdFund**:
  - `acceptDonation()`: Accepts donations and manages donor contributions.
  - `withdrawDonations(...)`: Allows the owner to withdraw funds after the campaign ends.
  - `depositToPrizeVault(...)`: Deposits funds into a prize vault.
  - `withdrawPrizeTokens(...)`: Withdraws prize tokens for the project owner.

## Installation

1. Clone the repository:

   ```bash
   git clone <repository-url>
   cd crowdfund
   ```

2. Install dependencies:

   ```bash
   forge install
   ```

3. Build the project:

   ```bash
   forge build
   ```

## Usage

### Deployment

Deploy the contract using Foundry:

```bash
forge script script/DeployFundFactory.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Interacting with the Contracts

1. **Creating a Fund**:

   - Use the `createFund(...)` function in the `FundFactory` contract to create a new crowdfunding campaign.

2. **Making a Donation**:

   - Send ETH to the `CrowdFund` contract address.
   - Must meet the minimum USD value requirement.

3. **Withdrawing Funds (Owner Only)**:

   - Call `withdrawDonations(...)` function in the `CrowdFund` contract.
   - Only accessible by the contract owner after the campaign ends.

4. **Managing Prize Vault**:
   - Use `depositToPrizeVault(...)` and `withdrawPrizeTokens(...)` to manage prize vault interactions.

## Testing

The project includes comprehensive tests covering all major functionality:

```bash
forge test
```

Key test cases include:

- Minimum donation validation.
- Owner access control.
- Multiple donor scenarios.
- ETH/USD conversion accuracy.
- Withdrawal functionality.
- Fallback and receive function testing.

## Security Considerations

- Ensure that the contract owner cannot withdraw funds before the campaign ends.
- Implement checks to prevent donations after the campaign has concluded.
- Use multiple reliable price feeds to ensure accurate conversion rates.
- Validate all external calls to prevent reentrancy attacks.

## Contributing

1. Fork the repository.
2. Create your feature branch.
3. Commit your changes.
4. Push to the branch.
5. Create a new Pull Request.

## License

MIT License

## Acknowledgments

- Chainlink for price feed oracles.
- Foundry for the development framework.
- OpenZeppelin for secure contract libraries.
