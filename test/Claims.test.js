const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployContracts } = require("./helpers/setup");
const params = require("../config/parameters");

describe("Claims", function () {
  let claims,
    cover,
    pool,
    assessment,
    governanceToken,
    mockOracle,
    deployer,
    user1,
    user2,
    user3;

  beforeEach(async function () {
    const contracts = await deployContracts();
    claims = contracts.claims;
    cover = contracts.cover;
    pool = contracts.pool;
    assessment = contracts.assessment;
    governanceToken = contracts.governanceToken;
    mockOracle = contracts.mockOracle;
    deployer = contracts.deployer;
    user1 = contracts.user1;
    user2 = contracts.user2;
    user3 = contracts.user3;

    // Fund pool
    await pool.deposit({ value: ethers.parseEther("1000") });

    // Purchase a cover for user1
    const coverAmount = ethers.parseEther("10");
    const coverPeriod = 365 * 24 * 60 * 60; // 1 year
    const mockProtocol = ethers.Wallet.createRandom().address;

    const quotation = contracts.quotation;
    const premium = await quotation.calculatePremium(
      coverAmount,
      coverPeriod,
      mockProtocol
    );

    await cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
      value: premium,
    });

    // Setup assessors
    const stakeAmount = params.MIN_STAKE_AMOUNT;
    const lockPeriod = params.STAKING_LOCK_PERIOD;

    // Distribute tokens to users
    await governanceToken.transfer(user2.address, stakeAmount * 2n);
    await governanceToken.transfer(user3.address, stakeAmount * 2n);

    // Register assessors (stake function doesn't need approval)
    await assessment.connect(user2).registerAsAssessor(stakeAmount, lockPeriod);
    await assessment.connect(user3).registerAsAssessor(stakeAmount, lockPeriod);
  });

  describe("Claim Submission", function () {
    it("Should submit a claim successfully", async function () {
      const proof = "Hack event: Protocol compromised on 2024-01-01";

      await expect(claims.connect(user1).submitClaim(0, proof))
        .to.emit(claims, "ClaimSubmitted")
        .withArgs(0, 0, user1.address, ethers.parseEther("10"), proof);

      const claim = await claims.getClaim(0);
      expect(claim.claimant).to.equal(user1.address);
      expect(claim.coverId).to.equal(0);
      expect(claim.resolved).to.be.false;
    });

    it("Should reject claim from non-cover-owner", async function () {
      await expect(
        claims.connect(user2).submitClaim(0, "Proof")
      ).to.be.revertedWith("Not cover owner");
    });

    it("Should reject claim for already claimed cover", async function () {
      // Submit and resolve a claim first
      await claims.connect(user1).submitClaim(0, "Proof");
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [params.CLAIM_VOTING_PERIOD + 1]);
      await ethers.provider.send("evm_mine", []);

      // Vote and resolve
      await claims.connect(user2).voteOnClaim(0, true);
      await claims.connect(user3).voteOnClaim(0, true);
      await claims.resolveClaim(0);

      // Try to submit another claim
      await expect(
        claims.connect(user1).submitClaim(0, "Another proof")
      ).to.be.revertedWith("Cover already claimed");
    });
  });

  describe("Voting", function () {
    beforeEach(async function () {
      await claims.connect(user1).submitClaim(0, "Hack proof");
    });

    it("Should allow assessors to vote", async function () {
      await expect(claims.connect(user2).voteOnClaim(0, true))
        .to.emit(claims, "ClaimVoted")
        .withArgs(0, user2.address, true, (value) => value > 0, 0);

      const claim = await claims.getClaim(0);
      expect(claim.yesVotes).to.be.gt(0);
    });

    it("Should reject votes from non-assessors", async function () {
      await expect(
        claims.connect(user1).voteOnClaim(0, true)
      ).to.be.revertedWith("Not a valid assessor");
    });

    it("Should reject duplicate votes", async function () {
      await claims.connect(user2).voteOnClaim(0, true);
      await expect(
        claims.connect(user2).voteOnClaim(0, false)
      ).to.be.revertedWith("Already voted");
    });
  });

  describe("Claim Resolution", function () {
    beforeEach(async function () {
      await claims.connect(user1).submitClaim(0, "Hack proof");
      // Set protocol as hacked
      await mockOracle.setProtocolHacked(
        (await cover.getCover(0)).coveredProtocol,
        true
      );
    });

    it("Should resolve claim and payout if approved", async function () {
      // Vote yes
      await claims.connect(user2).voteOnClaim(0, true);
      await claims.connect(user3).voteOnClaim(0, true);

      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [params.CLAIM_VOTING_PERIOD + 1]);
      await ethers.provider.send("evm_mine", []);

      const initialBalance = await ethers.provider.getBalance(user1.address);

      await expect(claims.resolveClaim(0))
        .to.emit(claims, "ClaimResolved")
        .withArgs(0, true, ethers.parseEther("10"));

      const claim = await claims.getClaim(0);
      expect(claim.resolved).to.be.true;
      expect(claim.approved).to.be.true;

      // Check payout (approximate due to gas)
      const finalBalance = await ethers.provider.getBalance(user1.address);
      expect(finalBalance - initialBalance).to.be.gte(ethers.parseEther("9.9"));
    });

    it("Should reject claim if not enough yes votes", async function () {
      // Vote no
      await claims.connect(user2).voteOnClaim(0, false);
      await claims.connect(user3).voteOnClaim(0, false);

      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [params.CLAIM_VOTING_PERIOD + 1]);
      await ethers.provider.send("evm_mine", []);

      await claims.resolveClaim(0);

      const claim = await claims.getClaim(0);
      expect(claim.resolved).to.be.true;
      expect(claim.approved).to.be.false;
    });

    it("Should reject resolution before voting period ends", async function () {
      await expect(claims.resolveClaim(0)).to.be.revertedWith(
        "Voting period not ended"
      );
    });
  });
});
