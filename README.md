# Decentralized Raffle Smart Contract

This project implements a decentralized, fair, and verifiably random raffle system using smart contracts on the Ethereum blockchain. It leverages Chainlink VRF (Verifiable Random Function) to ensure tamper-proof and transparent random number generation for winner selection.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technologies Used](#technologies-used)
- [Smart Contracts](#smart-contracts)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Deployment](#deployment)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

## Overview

The Decentralized Raffle Smart Contract allows participants to enter a raffle by paying an entrance fee. After a specified interval, the contract automatically selects a winner using Chainlink VRF, ensuring a fair and random selection process. The entire prize pool is then transferred to the winner.

## Features

- Decentralized and transparent raffle system
- Fair and verifiable random winner selection using Chainlink VRF
- Automated raffle cycles with customizable intervals
- Gas-efficient operations using Chainlink Automation for upkeep
- Comprehensive unit and integration tests
- Flexible configuration for different networks (mainnet, testnet, local)

## Technologies Used

- Solidity 0.8.19
- Foundry (for development, testing, and deployment)
- Chainlink VRF (Verifiable Random Function)
- Chainlink Automation (for automated upkeep)

## Smart Contracts

- `Raffle.sol`: The main raffle contract that handles entries, winner selection, and prize distribution.
- `VRFConsumerBaseV2Plus.sol`: Chainlink's VRF consumer contract for random number generation.
- `VRFV2PlusClient.sol`: Chainlink's VRF client for interacting with the VRF coordinator.

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- [Node.js](https://nodejs.org/) (for running scripts, if any)

### Installation

1. Clone the repository: https://github.com/hussainshafique7/decentralized-raffle
2. Install dependencies: forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit && forge install transmissions11/solmate@v6 --no-commit

## Testing

Run the test suite using Foundry: ` forge test ` 
For test coverage report: `forge coverage`

## Deployment

1. Set up your environment variables in a `.env` file:
 `PRIVATE_KEY=your_private_key`
 `ETHERSCAN_API_KEY=your_etherscan_api_key`
 `SEPOLIA_RPC_URL=your_sepolia_rpc_url`

2. Deploy to a network (e.g., Sepolia testnet): 
 `forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv`

 ## Usage

1. Enter the raffle by calling the `enterRaffle` function and sending the required entrance fee.
2. The raffle will automatically select a winner after the specified interval has passed.
3. The winner can be checked by calling the `getRecentWinner` function.

## Security Considerations

- The contract uses Chainlink VRF for secure random number generation.
- Entrance fees and prize distribution are handled carefully to prevent reentrancy attacks.
- The contract has been thoroughly tested, but we recommend a professional audit before mainnet deployment.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.