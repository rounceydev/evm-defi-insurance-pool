/**
 * Configuration parameters for the DeFi Insurance Pool
 * These values can be updated via governance
 * 
 * Note: Values that need to be converted to wei should use ethers.parseEther()
 * in the deployment/test scripts. This file contains string values for clarity.
 */

const { ethers } = require("ethers");

module.exports = {
  // Governance Token
  GOVERNANCE_TOKEN_NAME: "Insurance Governance Token",
  GOVERNANCE_TOKEN_SYMBOL: "IGT",
  INITIAL_SUPPLY: ethers.parseEther("1000000"), // 1M tokens

  // Pool Parameters
  MIN_POOL_CAPITAL: ethers.parseEther("100"), // Minimum ETH in pool
  MIN_CAPITAL_RATIO: 15000, // 150% (1.5x) minimum capital ratio (in basis points)

  // Cover Parameters
  MIN_COVER_AMOUNT: ethers.parseEther("0.1"), // Minimum cover amount
  MAX_COVER_AMOUNT: ethers.parseEther("1000"), // Maximum cover amount
  MIN_COVER_PERIOD: 30 * 24 * 60 * 60, // 30 days in seconds
  MAX_COVER_PERIOD: 365 * 24 * 60 * 60, // 1 year in seconds
  BASE_PREMIUM_RATE: 500, // 5% base premium (in basis points, 10000 = 100%)

  // Claims Parameters
  CLAIM_VOTING_PERIOD: 7 * 24 * 60 * 60, // 7 days
  MIN_VOTES_REQUIRED: 3, // Minimum number of votes to approve/reject
  APPROVAL_THRESHOLD: 6600, // 66% approval threshold (in basis points)

  // Staking Parameters
  MIN_STAKE_AMOUNT: ethers.parseEther("100"), // Minimum stake to become assessor
  STAKING_LOCK_PERIOD: 30 * 24 * 60 * 60, // 30 days lock period

  // Quotation Parameters
  RISK_FACTOR_PROTOCOL: 1000, // 10% additional risk for protocol covers
  RISK_FACTOR_ASSET: 500, // 5% additional risk for asset covers
};
