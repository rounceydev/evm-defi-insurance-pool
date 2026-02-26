const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { deployContracts } = require("./helpers/setup");
const params = require("../config/parameters");

describe("Pool", function () {
  let pool, mockStablecoin, deployer, user1;

  beforeEach(async function () {
    const contracts = await deployContracts();
    pool = contracts.pool;
    mockStablecoin = contracts.mockStablecoin;
    deployer = contracts.deployer;
    user1 = contracts.user1;
  });

  describe("Deployment", function () {
    it("Should set the right initial parameters", async function () {
      expect(await pool.minCapitalRatio()).to.equal(params.MIN_CAPITAL_RATIO);
      expect(await pool.minPoolCapital()).to.equal(params.MIN_POOL_CAPITAL);
    });

    it("Should have correct roles", async function () {
      const GOVERNOR_ROLE = await pool.GOVERNOR_ROLE();
      expect(await pool.hasRole(GOVERNOR_ROLE, deployer.address)).to.be.true;
    });
  });

  describe("Deposits", function () {
    it("Should accept ETH deposits", async function () {
      const depositAmount = ethers.parseEther("10");
      await expect(pool.deposit({ value: depositAmount }))
        .to.emit(pool, "Deposit")
        .withArgs(deployer.address, depositAmount);

      expect(await pool.totalCapital()).to.equal(depositAmount);
    });

    it("Should accept stablecoin deposits", async function () {
      const depositAmount = ethers.parseUnits("1000", 6);
      await mockStablecoin.approve(await pool.getAddress(), depositAmount);
      await expect(pool.depositStablecoin(depositAmount))
        .to.emit(pool, "Deposit")
        .withArgs(deployer.address, depositAmount);

      expect(await pool.stablecoinBalance()).to.equal(depositAmount);
    });

    it("Should reject zero deposits", async function () {
      await expect(pool.deposit({ value: 0 })).to.be.revertedWith(
        "Must deposit more than 0"
      );
    });
  });

  describe("Withdrawals", function () {
    beforeEach(async function () {
      await pool.deposit({ value: ethers.parseEther("100") });
    });

    it("Should allow governor to withdraw", async function () {
      const withdrawAmount = ethers.parseEther("50");
      await expect(pool.withdraw(withdrawAmount))
        .to.emit(pool, "Withdrawal")
        .withArgs(deployer.address, withdrawAmount);

      expect(await pool.totalCapital()).to.equal(ethers.parseEther("50"));
    });

    it("Should reject withdrawals that violate solvency", async function () {
      // Set liabilities
      await pool.updateLiabilities(ethers.parseEther("80"));
      // Try to withdraw too much
      await expect(pool.withdraw(ethers.parseEther("50"))).to.be.revertedWith(
        "Withdrawal would violate solvency requirements"
      );
    });

    it("Should reject non-governor withdrawals", async function () {
      await expect(
        pool.connect(user1).withdraw(ethers.parseEther("10"))
      ).to.be.reverted;
    });
  });

  describe("Solvency", function () {
    it("Should calculate solvency ratio correctly", async function () {
      await pool.deposit({ value: ethers.parseEther("150") });
      await pool.updateLiabilities(ethers.parseEther("100"));

      const ratio = await pool.getSolvencyRatio();
      expect(ratio).to.equal(15000); // 150%
    });

    it("Should check solvency correctly", async function () {
      await pool.deposit({ value: ethers.parseEther("150") });
      await pool.updateLiabilities(ethers.parseEther("100"));

      expect(await pool.isSolvent()).to.be.true;

      // Reduce capital below required
      await pool.withdraw(ethers.parseEther("50"));
      expect(await pool.isSolvent()).to.be.false;
    });
  });

  describe("Pausability", function () {
    it("Should pause and unpause", async function () {
      await pool.pause();
      await expect(pool.deposit({ value: ethers.parseEther("1") })).to.be
        .reverted;

      await pool.unpause();
      await pool.deposit({ value: ethers.parseEther("1") });
      expect(await pool.totalCapital()).to.equal(ethers.parseEther("1"));
    });
  });
});
