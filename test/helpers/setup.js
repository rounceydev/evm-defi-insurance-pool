const { ethers, upgrades } = require("hardhat");
const params = require("../../config/parameters");

/**
 * Deploy all contracts for testing
 */
async function deployContracts() {
  const [deployer, user1, user2, user3] = await ethers.getSigners();

  // Deploy mock contracts
  const MockStablecoin = await ethers.getContractFactory("MockStablecoin");
  const mockStablecoin = await MockStablecoin.deploy();

  const MockOracle = await ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy();

  // Deploy CoverNFT (non-upgradeable)
  const CoverNFT = await ethers.getContractFactory("CoverNFT");
  const coverNFT = await CoverNFT.deploy();

  // Deploy GovernanceToken (upgradeable)
  const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
  const governanceToken = await upgrades.deployProxy(
    GovernanceToken,
    [
      params.GOVERNANCE_TOKEN_NAME,
      params.GOVERNANCE_TOKEN_SYMBOL,
      params.INITIAL_SUPPLY,
      deployer.address,
    ],
    { initializer: "initialize" }
  );
  await governanceToken.waitForDeployment();

  // Deploy Pool (upgradeable)
  const Pool = await ethers.getContractFactory("Pool");
  const pool = await upgrades.deployProxy(
    Pool,
    [
      deployer.address,
      await mockStablecoin.getAddress(),
      params.MIN_CAPITAL_RATIO,
      params.MIN_POOL_CAPITAL,
    ],
    { initializer: "initialize" }
  );
  await pool.waitForDeployment();

  // Deploy Quotation (upgradeable)
  const Quotation = await ethers.getContractFactory("Quotation");
  const quotation = await upgrades.deployProxy(
    Quotation,
    [
      deployer.address,
      await mockOracle.getAddress(),
      params.BASE_PREMIUM_RATE,
      params.RISK_FACTOR_PROTOCOL,
      params.RISK_FACTOR_ASSET,
      params.MIN_COVER_PERIOD,
      params.MAX_COVER_PERIOD,
    ],
    { initializer: "initialize" }
  );
  await quotation.waitForDeployment();

  // Deploy Cover (upgradeable)
  const Cover = await ethers.getContractFactory("Cover");
  const cover = await upgrades.deployProxy(
    Cover,
    [
      deployer.address,
      await coverNFT.getAddress(),
      await pool.getAddress(),
      await quotation.getAddress(),
      params.MIN_COVER_AMOUNT,
      params.MAX_COVER_AMOUNT,
    ],
    { initializer: "initialize" }
  );
  await cover.waitForDeployment();

  // Grant MINTER_ROLE to Cover contract
  await coverNFT.grantRole(
    await coverNFT.MINTER_ROLE(),
    await cover.getAddress()
  );

  // Grant PAYOUT_ROLE to Cover and Claims contracts
  const PAYOUT_ROLE = await pool.PAYOUT_ROLE();
  await pool.grantRole(PAYOUT_ROLE, await cover.getAddress());

  // Deploy Assessment (upgradeable)
  const Assessment = await ethers.getContractFactory("Assessment");
  const assessment = await upgrades.deployProxy(
    Assessment,
    [
      deployer.address,
      await governanceToken.getAddress(),
      params.MIN_STAKE_AMOUNT,
    ],
    { initializer: "initialize" }
  );
  await assessment.waitForDeployment();

  // Deploy Claims (upgradeable)
  const Claims = await ethers.getContractFactory("Claims");
  const claims = await upgrades.deployProxy(
    Claims,
    [
      deployer.address,
      await cover.getAddress(),
      await pool.getAddress(),
      await assessment.getAddress(),
      await mockOracle.getAddress(),
      params.CLAIM_VOTING_PERIOD,
      params.MIN_VOTES_REQUIRED,
      params.APPROVAL_THRESHOLD,
    ],
    { initializer: "initialize" }
  );
  await claims.waitForDeployment();

  // Grant GOVERNOR_ROLE to Claims contract for marking covers as claimed
  const GOVERNOR_ROLE = await cover.GOVERNOR_ROLE();
  await cover.grantRole(GOVERNOR_ROLE, await claims.getAddress());

  // Grant GOVERNOR_ROLE to Claims contract for marking votes
  const ASSESSMENT_GOVERNOR_ROLE = await assessment.GOVERNOR_ROLE();
  await assessment.grantRole(
    ASSESSMENT_GOVERNOR_ROLE,
    await claims.getAddress()
  );

  // Grant PAYOUT_ROLE to Claims contract
  await pool.grantRole(PAYOUT_ROLE, await claims.getAddress());

  return {
    deployer,
    user1,
    user2,
    user3,
    mockStablecoin,
    mockOracle,
    coverNFT,
    governanceToken,
    pool,
    quotation,
    cover,
    assessment,
    claims,
  };
}

module.exports = {
  deployContracts,
};
