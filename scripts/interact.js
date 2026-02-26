const { ethers } = require("hardhat");

/**
 * Example interaction script
 * Replace contract addresses with your deployed addresses
 */
async function main() {
  // Replace with your deployed contract addresses
  const COVER_ADDRESS = "0x...";
  const POOL_ADDRESS = "0x...";
  const GOVERNANCE_TOKEN_ADDRESS = "0x...";
  const ASSESSMENT_ADDRESS = "0x...";
  const CLAIMS_ADDRESS = "0x...";

  const [user] = await ethers.getSigners();
  console.log("Interacting with contracts as:", user.address);

  // Example: Purchase a cover
  const cover = await ethers.getContractAt("Cover", COVER_ADDRESS);
  const quotation = await ethers.getContractAt("Quotation", "0x..."); // Replace with actual address

  const coverAmount = ethers.parseEther("10");
  const coverPeriod = 30 * 24 * 60 * 60; // 30 days
  const mockProtocol = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"; // Example protocol address

  const premium = await quotation.calculatePremium(
    coverAmount,
    coverPeriod,
    mockProtocol
  );

  console.log("Premium calculated:", ethers.formatEther(premium), "ETH");

  // Purchase cover
  const tx = await cover.purchaseCover(mockProtocol, coverAmount, coverPeriod, {
    value: premium,
  });
  await tx.wait();
  console.log("Cover purchased! TX:", tx.hash);

  // Example: Become an assessor
  const governanceToken = await ethers.getContractAt(
    "GovernanceToken",
    GOVERNANCE_TOKEN_ADDRESS
  );
  const assessment = await ethers.getContractAt(
    "Assessment",
    ASSESSMENT_ADDRESS
  );

  const stakeAmount = ethers.parseEther("100");
  const lockPeriod = 30 * 24 * 60 * 60; // 30 days

  // Approve and stake
  await governanceToken.approve(GOVERNANCE_TOKEN_ADDRESS, stakeAmount);
  await governanceToken.stake(stakeAmount, lockPeriod);
  await assessment.registerAsAssessor(stakeAmount, lockPeriod);
  console.log("Registered as assessor!");

  // Example: Submit a claim
  const claims = await ethers.getContractAt("Claims", CLAIMS_ADDRESS);
  const coverId = 0; // Replace with actual cover ID
  const proof = "Hack event: Protocol compromised";

  const claimTx = await claims.submitClaim(coverId, proof);
  await claimTx.wait();
  console.log("Claim submitted! TX:", claimTx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
