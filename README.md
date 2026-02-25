# EVM DeFi Insurance Pool

A decentralized DeFi insurance pool smart contract system inspired by Nexus Mutual, built for covering smart contract risks in the Ethereum ecosystem.

## 📋 Project Overview

This project is a simplified educational clone of Nexus Mutual's decentralized insurance protocol. It enables users to:

- **Purchase insurance covers** for DeFi protocols and smart contracts
- **Stake governance tokens** to become assessors and participate in claim evaluation
- **Submit claims** when covered protocols experience hacks or failures
- **Vote on claims** through a decentralized assessment process
- **Receive payouts** from the insurance pool when claims are approved

The system uses a mutual insurance model where premiums are pooled together, and claims are assessed by token-holding members of the community.

## ✨ Key Features

### Core Functionality

1. **Cover Purchasing**
   - Users can purchase insurance covers for specific protocols/assets
   - Covers are represented as ERC-721 NFTs
   - Premiums are calculated based on cover amount, duration, and risk factors
   - Premiums are paid in ETH or stablecoins

2. **Claims Assessment**
   - Policy holders can submit claims with proof of loss
   - Assessors (staked token holders) vote on claim validity
   - Claims are resolved based on voting majority and approval threshold
   - Approved claims trigger payouts from the insurance pool

3. **Capital Pooling**
   - ETH and stablecoins are pooled together
   - Solvency requirements ensure adequate capital coverage
   - Capital ratio monitoring prevents over-leverage

4. **Staking & Governance**
   - Users stake governance tokens to become assessors
   - Staked tokens provide voting power in claim assessments
   - Governance functions allow parameter updates (premium rates, voting thresholds, etc.)

5. **Risk Management**
   - Premium calculations incorporate risk scores from oracles
   - Minimum capital ratios ensure pool solvency
   - Time-locked stakes prevent gaming

## 🏗️ Architecture

### Contract Structure

```
┌─────────────────────────────────────────────────────────────┐
│                      GovernanceToken                        │
│              (ERC-20 with staking & voting)                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                        Assessment                           │
│              (Manages assessor registration)                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                          Claims                              │
│         (Claim submission, voting, resolution)               │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        ▼                             ▼
┌──────────────┐              ┌──────────────┐
│    Cover     │              │     Pool     │
│ (Purchases,  │              │  (Capital    │
│  NFTs)       │              │  Management) │
└──────┬───────┘              └──────┬───────┘
       │                             │
       └──────────────┬──────────────┘
                      ▼
            ┌─────────────────┐
            │   Quotation     │
            │ (Premium Calc)  │
            └─────────────────┘
```

### Core Contracts

- **Pool.sol**: Manages the insurance pool capital (ETH/stablecoins), handles deposits, withdrawals, and payouts
- **Cover.sol**: Handles cover purchases, mints ERC-721 CoverNFTs, collects premiums
- **Claims.sol**: Manages claim submission, voting, and resolution
- **Assessment.sol**: Manages assessor registration and voting power
- **GovernanceToken.sol**: ERC-20 token with staking capabilities for membership and voting
- **Quotation.sol**: Calculates insurance premiums based on risk factors
- **CoverNFT.sol**: ERC-721 NFT representing insurance policies

### Mock Contracts

- **MockStablecoin.sol**: Mock ERC-20 stablecoin for testing
- **MockOracle.sol**: Mock oracle for risk assessment and hack detection

## 🚀 Setup Instructions

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Hardhat

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd evm-defi-insurance-pool
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

3. Create a `.env` file (copy from `.env.example`):
```bash
cp .env.example .env
```

4. Configure your `.env` file with:
```
SEPOLIA_RPC_URL=your_rpc_url
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

### Compilation

Compile the contracts:
```bash
npm run compile
# or
npx hardhat compile
```

## 🧪 Running Tests

Run the test suite:
```bash
npm run test
# or
npx hardhat test
```

Run tests with coverage:
```bash
npm run test:coverage
```

### Test Coverage

The test suite includes:
- ✅ Cover purchase flows
- ✅ Claim submission and resolution
- ✅ Voting mechanics
- ✅ Solvency checks
- ✅ Staking/unstaking
- ✅ Edge cases (invalid claims, insufficient pool, unauthorized actions, time-based expirations)

## 📦 Deployment

### Local Deployment

1. Start a local Hardhat node:
```bash
npm run node
# or
npx hardhat node
```

2. In a new terminal, deploy contracts:
```bash
npm run deploy:local
# or
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet Deployment (Sepolia)

Deploy to Sepolia testnet:
```bash
npm run deploy:sepolia
# or
npx hardhat run scripts/deploy.js --network sepolia
```

### Verify Contracts

After deployment, verify contracts on Etherscan:
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 📁 Project Structure

```
evm-defi-insurance-pool/
├── contracts/
│   ├── core/
│   │   ├── Pool.sol
│   │   ├── Cover.sol
│   │   ├── Claims.sol
│   │   ├── Assessment.sol
│   │   └── Quotation.sol
│   ├── tokens/
│   │   ├── GovernanceToken.sol
│   │   └── CoverNFT.sol
│   ├── interfaces/
│   │   ├── IPool.sol
│   │   ├── ICover.sol
│   │   ├── IClaims.sol
│   │   └── IQuotation.sol
│   └── mocks/
│       ├── MockStablecoin.sol
│       └── MockOracle.sol
├── scripts/
│   ├── deploy.js
│   └── interact.js
├── test/
│   ├── helpers/
│   │   └── setup.js
│   ├── Pool.test.js
│   ├── Cover.test.js
│   ├── Claims.test.js
│   ├── GovernanceToken.test.js
│   └── Quotation.test.js
├── config/
│   └── parameters.js
├── hardhat.config.js
├── package.json
└── README.md
```

## 📞 Support

- telegram: https://t.me/rouncey
- twitter:  https://x.com/rouncey_
