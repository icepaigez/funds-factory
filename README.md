# CrowdFund Smart Contract

A decentralized crowdfunding platform built on Ethereum using Foundry.

## Overview

This smart contract allows users to create and participate in crowdfunding campaigns with the following features:

- Minimum donation amount in USD (converted to ETH)
- Real-time ETH/USD price feed integration via Chainlink
- Secure fund management
- Withdrawal functionality for campaign owner
- Multiple donor tracking
- Donation state management
- Optional PoolTogether integration for no-loss lottery participation

## Technical Stack

- Solidity ^0.8.18
- Foundry for testing and deployment
- Chainlink Price Feeds
- PoolTogether V5 Protocol

## Contract Features

### Core Functionality

1. **Minimum Donation**

   - Set minimum donation amount in USD
   - Automatic conversion to ETH using Chainlink price feeds
   - Currently set to $1 minimum

2. **Donation Management**

   - Track individual donor contributions
   - Maintain total donations
   - Store donor addresses for transparency

3. **Owner Controls**

   - Secure withdrawal mechanism
   - Only owner can withdraw funds
   - State management for donation periods

4. **PoolTogether Integration**
   - Option to deposit donations into PoolTogether's no-loss lottery
   - Potential to earn additional yields through prize winnings
   - Maintain liquidity while participating in prize games
   - Ability to withdraw from prize pool at any time

### Security Features

- Custom error messages for gas optimization
- Access control modifiers
- Checks-Effects-Interactions pattern
- Reentrancy protection

## Testing

The project includes comprehensive tests covering all major functionality:

```bash
forge test
```

Key test cases include:

- Minimum donation validation
- Owner access control
- Multiple donor scenarios
- ETH/USD conversion accuracy
- Withdrawal functionality
- Fallback and receive function testing

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
forge script script/DeployCrowdFund.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Interacting with the Contract

1. **Making a Donation**

   - Send ETH to the contract address
   - Must meet minimum USD value requirement

2. **Withdrawing Funds (Owner Only)**
   - Call `withdrawDonations()` function
   - Only accessible by contract owner

## Contract Architecture

### Main Components

1. **State Variables**

   - `owner`: Contract deployer address
   - `minimumDonation`: Minimum donation amount in USD
   - `totalDonations`: Total ETH donated
   - `donors`: Array of donor addresses
   - `donorAmounts`: Mapping of donor addresses to amounts
   - `poolTogetherDeposited`: Track amounts deposited in PoolTogether
   - `isParticipatingInPrizePool`: Current PoolTogether participation status

2. **Key Functions**
   - `acceptDonation()`: Accept and process donations
   - `withdrawDonations()`: Allow owner to withdraw funds
   - `minDonationValueToEth()`: Convert USD to ETH
   - `depositIntoPoolTogether()`: Deposit funds into PoolTogether prize pool
   - `withdrawFromPoolTogether()`: Withdraw funds from PoolTogether prize pool
   - Various getter functions for contract state

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

MIT License

## Acknowledgments

- Chainlink for price feed oracles
- Foundry for development framework
- PoolTogether for no-loss prize games integration
