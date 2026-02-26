const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployContracts } = require("./helpers/setup");
const params = require("../config/parameters");

describe("Quotation", function () {
  let quotation, mockOracle, deployer;

  beforeEach(async function () {
    const contracts = await deployContracts();
    quotation = contracts.quotation;
    mockOracle = contracts.mockOracle;
    deployer = contracts.deployer;
  });

  describe("Premium Calculation", function () {
    it("Should calculate premium for a cover", async function () {
      const coverAmount = ethers.parseEther("100");
      const coverPeriod = 30 * 24 * 60 * 60; // 30 days
      const mockProtocol = ethers.Wallet.createRandom().address;

      // Set risk score
      await mockOracle.setRiskScore(mockProtocol, 1000); // 10%

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      expect(premium).to.be.gt(0);
      // Premium should be less than cover amount
      expect(premium).to.be.lt(coverAmount);
    });

    it("Should reject calculation for invalid cover period", async function () {
      const coverAmount = ethers.parseEther("100");
      const invalidPeriod = 10 * 24 * 60 * 60; // 10 days (below minimum)

      await expect(
        quotation.calculatePremium(coverAmount, invalidPeriod, ethers.ZeroAddress)
      ).to.be.revertedWith("Cover period out of range");
    });

    it("Should apply risk factors correctly", async function () {
      const coverAmount = ethers.parseEther("100");
      const coverPeriod = 365 * 24 * 60 * 60; // 1 year
      const mockProtocol = ethers.Wallet.createRandom().address;

      // Set high risk score
      await mockOracle.setRiskScore(mockProtocol, 5000); // 50%

      const highRiskPremium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      // Set low risk score
      await mockOracle.setRiskScore(mockProtocol, 100); // 1%

      const lowRiskPremium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      expect(highRiskPremium).to.be.gt(lowRiskPremium);
    });

    it("Should enforce minimum premium", async function () {
      const coverAmount = ethers.parseEther("1");
      const coverPeriod = 30 * 24 * 60 * 60;
      const mockProtocol = ethers.Wallet.createRandom().address;

      const premium = await quotation.calculatePremium(
        coverAmount,
        coverPeriod,
        mockProtocol
      );

      // Minimum premium should be 0.1% of cover amount
      const minPremium = (coverAmount * 10n) / 10000n;
      expect(premium).to.be.gte(minPremium);
    });
  });
});
