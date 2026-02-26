const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployContracts } = require("./helpers/setup");
const params = require("../config/parameters");

describe("GovernanceToken", function () {
  let governanceToken, deployer, user1;

  beforeEach(async function () {
    const contracts = await deployContracts();
    governanceToken = contracts.governanceToken;
    deployer = contracts.deployer;
    user1 = contracts.user1;
  });

  describe("Deployment", function () {
    it("Should set the right name and symbol", async function () {
      expect(await governanceToken.name()).to.equal(
        params.GOVERNANCE_TOKEN_NAME
      );
      expect(await governanceToken.symbol()).to.equal(
        params.GOVERNANCE_TOKEN_SYMBOL
      );
    });

    it("Should mint initial supply to deployer", async function () {
      expect(await governanceToken.balanceOf(deployer.address)).to.equal(
        params.INITIAL_SUPPLY
      );
    });
  });

  describe("Staking", function () {
    it("Should allow staking tokens", async function () {
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60;

      // Stake function uses _transfer internally, no approval needed
      await expect(governanceToken.stake(stakeAmount, lockPeriod))
        .to.emit(governanceToken, "TokensStaked")
        .withArgs(deployer.address, stakeAmount, (value) => value > 0);

      expect(await governanceToken.stakedBalance(deployer.address)).to.equal(
        stakeAmount
      );
      expect(await governanceToken.totalStaked()).to.equal(stakeAmount);
    });

    it("Should reject staking more than balance", async function () {
      const stakeAmount = params.INITIAL_SUPPLY + 1n;
      const lockPeriod = 30 * 24 * 60 * 60;

      await expect(
        governanceToken.stake(stakeAmount, lockPeriod)
      ).to.be.revertedWith("Insufficient balance to stake");
    });

    it("Should allow unstaking after lock period", async function () {
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60;

      const initialBalance = await governanceToken.balanceOf(deployer.address);
      await governanceToken.stake(stakeAmount, lockPeriod);

      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [lockPeriod + 1]);
      await ethers.provider.send("evm_mine", []);

      await expect(governanceToken.unstake(stakeAmount))
        .to.emit(governanceToken, "TokensUnstaked")
        .withArgs(deployer.address, stakeAmount);

      expect(await governanceToken.balanceOf(deployer.address)).to.equal(
        initialBalance
      );
      expect(await governanceToken.stakedBalance(deployer.address)).to.equal(0);
    });

    it("Should reject unstaking before lock period", async function () {
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60;

      await governanceToken.stake(stakeAmount, lockPeriod);

      await expect(governanceToken.unstake(stakeAmount)).to.be.revertedWith(
        "Stake is still locked"
      );
    });
  });

  describe("Voting Power", function () {
    it("Should calculate voting power correctly", async function () {
      const stakeAmount = ethers.parseEther("100");
      const lockPeriod = 30 * 24 * 60 * 60;

      const initialBalance = await governanceToken.balanceOf(deployer.address);
      await governanceToken.stake(stakeAmount, lockPeriod);

      const votingPower = await governanceToken.getVotingPower(deployer.address);
      // Voting power = current balance + staked amount
      const expectedBalance = initialBalance - stakeAmount;
      expect(votingPower).to.equal(expectedBalance + stakeAmount);
    });
  });
});
