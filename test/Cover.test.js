const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployContracts } = require("./helpers/setup");
const params = require("../config/parameters");

describe("Cover", function () {
  let cover, pool, quotation, coverNFT, mockOracle, deployer, user1;

  beforeEach(async function () {
    const contracts = await deployContracts();
    cover = contracts.cover;
    pool = contracts.pool;
    quotation = contracts.quotation;
    coverNFT = contracts.coverNFT;
    mockOracle = contracts.mockOracle;
    deployer = contracts.deployer;
    user1 = contracts.user1;

    // Fund pool
    await pool.deposit({ value: ethers.parseEther("1000") });
  });

  describe("Cover Purchase", function () {
    it("Should purchase a cover successfully", async function () {
      const coverAmount = ethers.parseEther("10");
      const coverPeriod = 30 * 24 * 60 * 60; // 30 days
      const mockProtocol = ethers.Wallet.createRandom().address;

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      await expect(
        cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
          value: premium,
        })
      )
        .to.emit(cover, "CoverPurchased")
        .withArgs(
          0,
          user1.address,
          mockProtocol,
          coverAmount,
          premium,
          (value) => value > 0,
          (value) => value > 0
        );

      const coverData = await cover.getCover(0);
      expect(coverData.buyer).to.equal(user1.address);
      expect(coverData.coverAmount).to.equal(coverAmount);
      expect(coverData.active).to.be.true;
    });

    it("Should mint NFT when purchasing cover", async function () {
      const coverAmount = ethers.parseEther("10");
      const coverPeriod = 30 * 24 * 60 * 60;
      const mockProtocol = ethers.Wallet.createRandom().address;

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      await cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
        value: premium,
      });

      expect(await coverNFT.ownerOf(0)).to.equal(user1.address);
    });

    it("Should reject cover purchase below minimum", async function () {
      const coverAmount = ethers.parseEther("0.05"); // Below minimum
      const coverPeriod = 30 * 24 * 60 * 60;
      const mockProtocol = ethers.Wallet.createRandom().address;

      await expect(
        cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
          value: ethers.parseEther("1"),
        })
      ).to.be.revertedWith("Cover amount too low");
    });

    it("Should reject cover purchase if pool is not solvent", async function () {
      // Make pool insolvent
      await pool.updateLiabilities(ethers.parseEther("2000"));

      const coverAmount = ethers.parseEther("10");
      const coverPeriod = 30 * 24 * 60 * 60;
      const mockProtocol = ethers.Wallet.createRandom().address;

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      await expect(
        cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
          value: premium,
        })
      ).to.be.revertedWith("Pool is not solvent");
    });

    it("Should update pool liabilities when cover is purchased", async function () {
      const coverAmount = ethers.parseEther("50");
      const coverPeriod = 30 * 24 * 60 * 60;
      const mockProtocol = ethers.Wallet.createRandom().address;

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      await cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
        value: premium,
      });

      expect(await pool.totalLiabilities()).to.equal(coverAmount);
    });
  });

  describe("Cover Status", function () {
    it("Should check if cover is active", async function () {
      const coverAmount = ethers.parseEther("10");
      const coverPeriod = 30 * 24 * 60 * 60;
      const mockProtocol = ethers.Wallet.createRandom().address;

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      await cover.connect(user1).purchaseCover(mockProtocol, coverAmount, coverPeriod, {
        value: premium,
      });

      expect(await cover.isCoverActive(0)).to.be.true;
    });
  });
});
