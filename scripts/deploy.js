const { ethers, upgrades } = require("hardhat");
const params = require("../config/parameters");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy mock contracts
  console.log("\n1. Deploying Mock Contracts...");
  const MockStablecoin = await ethers.getContractFactory("MockStablecoin");
  const mockStablecoin = await MockStablecoin.deploy();
  await mockStablecoin.waitForDeployment();
  console.log("MockStablecoin deployed to:", await mockStablecoin.getAddress());

  const MockOracle = await ethers.getContractFactory("MockOracle");
  const mockOracle = await MockOracle.deploy();
  await mockOracle.waitForDeployment();
  console.log("MockOracle deployed to:", await mockOracle.getAddress());

  // Deploy CoverNFT (non-upgradeable)
  console.log("\n2. Deploying CoverNFT...");
  const CoverNFT = await ethers.getContractFactory("CoverNFT");
  const coverNFT = await CoverNFT.deploy();
  await coverNFT.waitForDeployment();
  console.log("CoverNFT deployed to:", await coverNFT.getAddress());

  // Deploy GovernanceToken (upgradeable)
  console.log("\n3. Deploying GovernanceToken...");
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
  console.log("GovernanceToken deployed to:", await governanceToken.getAddress());

  // Deploy Pool (upgradeable)
  console.log("\n4. Deploying Pool...");
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
  console.log("Pool deployed to:", await pool.getAddress());

  // Deploy Quotation (upgradeable)
  console.log("\n5. Deploying Quotation...");
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
  console.log("Quotation deployed to:", await quotation.getAddress());

  // Deploy Cover (upgradeable)
  console.log("\n6. Deploying Cover...");
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
  console.log("Cover deployed to:", await cover.getAddress());

  // Grant MINTER_ROLE to Cover contract
  console.log("\n7. Setting up roles...");
  const MINTER_ROLE = await coverNFT.MINTER_ROLE();
  await coverNFT.grantRole(MINTER_ROLE, await cover.getAddress());
  console.log("Granted MINTER_ROLE to Cover contract");

  // Grant PAYOUT_ROLE to Cover and Claims contracts
  const PAYOUT_ROLE = await pool.PAYOUT_ROLE();
  await pool.grantRole(PAYOUT_ROLE, await cover.getAddress());
  console.log("Granted PAYOUT_ROLE to Cover contract");

  // Deploy Assessment (upgradeable)
  console.log("\n8. Deploying Assessment...");
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
  console.log("Assessment deployed to:", await assessment.getAddress());

  // Deploy Claims (upgradeable)
  console.log("\n9. Deploying Claims...");
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
  console.log("Claims deployed to:", await claims.getAddress());

  // Grant additional roles
  const GOVERNOR_ROLE_COVER = await cover.GOVERNOR_ROLE();
  await cover.grantRole(GOVERNOR_ROLE_COVER, await claims.getAddress());
  console.log("Granted GOVERNOR_ROLE to Claims contract (for Cover)");

  const GOVERNOR_ROLE_ASSESSMENT = await assessment.GOVERNOR_ROLE();
  await assessment.grantRole(GOVERNOR_ROLE_ASSESSMENT, await claims.getAddress());
  console.log("Granted GOVERNOR_ROLE to Claims contract (for Assessment)");

  await pool.grantRole(PAYOUT_ROLE, await claims.getAddress());
  console.log("Granted PAYOUT_ROLE to Claims contract");

  // Summary
  console.log("\n=== Deployment Summary ===");
  console.log("MockStablecoin:", await mockStablecoin.getAddress());
  console.log("MockOracle:", await mockOracle.getAddress());
  console.log("CoverNFT:", await coverNFT.getAddress());
  console.log("GovernanceToken:", await governanceToken.getAddress());
  console.log("Pool:", await pool.getAddress());
  console.log("Quotation:", await quotation.getAddress());
  console.log("Cover:", await cover.getAddress());
  console.log("Assessment:", await assessment.getAddress());
  console.log("Claims:", await claims.getAddress());
  console.log("\nAll contracts deployed successfully!");

  // Save deployment addresses (optional - can be extended to save to a file)
  const deploymentInfo = {
    network: network.name,
    deployer: deployer.address,
    contracts: {
      MockStablecoin: await mockStablecoin.getAddress(),
      MockOracle: await mockOracle.getAddress(),
      CoverNFT: await coverNFT.getAddress(),
      GovernanceToken: await governanceToken.getAddress(),
      Pool: await pool.getAddress(),
      Quotation: await quotation.getAddress(),
      Cover: await cover.getAddress(),
      Assessment: await assessment.getAddress(),
      Claims: await claims.getAddress(),
    },
  };

  console.log("\nDeployment info:", JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
