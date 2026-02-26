// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../interfaces/IQuotation.sol";
import "../mocks/MockOracle.sol";

/**
 * @title Quotation
 * @notice Calculates insurance premiums based on cover parameters and risk factors
 */
contract Quotation is
    Initializable,
    IQuotation,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @notice Base premium rate (in basis points, e.g., 500 = 5%)
    uint256 public basePremiumRate;

    /// @notice Risk factor for protocol covers (in basis points)
    uint256 public riskFactorProtocol;

    /// @notice Risk factor for asset covers (in basis points)
    uint256 public riskFactorAsset;

    /// @notice Oracle for risk assessment
    MockOracle public oracle;

    /// @notice Minimum cover period (in seconds)
    uint256 public minCoverPeriod;

    /// @notice Maximum cover period (in seconds)
    uint256 public maxCoverPeriod;

    event PremiumCalculated(
        address indexed coveredProtocol,
        uint256 coverAmount,
        uint256 coverPeriod,
        uint256 premium
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the Quotation contract
     * @param admin Admin address
     * @param _oracle Oracle address
     * @param _basePremiumRate Base premium rate (in basis points)
     * @param _riskFactorProtocol Protocol risk factor (in basis points)
     * @param _riskFactorAsset Asset risk factor (in basis points)
     * @param _minCoverPeriod Minimum cover period
     * @param _maxCoverPeriod Maximum cover period
     */
    function initialize(
        address admin,
        address _oracle,
        uint256 _basePremiumRate,
        uint256 _riskFactorProtocol,
        uint256 _riskFactorAsset,
        uint256 _minCoverPeriod,
        uint256 _maxCoverPeriod
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);

        oracle = MockOracle(_oracle);
        basePremiumRate = _basePremiumRate;
        riskFactorProtocol = _riskFactorProtocol;
        riskFactorAsset = _riskFactorAsset;
        minCoverPeriod = _minCoverPeriod;
        maxCoverPeriod = _maxCoverPeriod;
    }

    /**
     * @notice Calculate premium for a cover
     * @param coverAmount Amount to cover
     * @param coverPeriod Cover period in seconds
     * @param coveredProtocol Protocol or asset address being covered
     * @return premium Calculated premium amount
     */
    function calculatePremium(
        uint256 coverAmount,
        uint256 coverPeriod,
        address coveredProtocol
    ) external view override returns (uint256 premium) {
        require(coverAmount > 0, "Cover amount must be greater than 0");
        require(
            coverPeriod >= minCoverPeriod && coverPeriod <= maxCoverPeriod,
            "Cover period out of range"
        );

        // Base premium calculation: (coverAmount * baseRate * period) / (365 days * 10000)
        uint256 annualPremium = (coverAmount * basePremiumRate) / 10000;
        uint256 periodPremium = (annualPremium * coverPeriod) /
            (365 days);

        // Get risk score from oracle (0-10000, where 10000 = 100%)
        uint256 riskScore = oracle.getRiskScore(coveredProtocol);

        // Apply risk factor based on protocol type
        uint256 riskFactor = coveredProtocol != address(0)
            ? riskFactorProtocol
            : riskFactorAsset;

        // Calculate final premium with risk adjustment
        // Premium = periodPremium * (1 + riskFactor/10000) * (1 + riskScore/10000)
        uint256 riskAdjustedPremium = (periodPremium *
            (10000 + riskFactor)) / 10000;
        premium =
            (riskAdjustedPremium * (10000 + riskScore)) /
            10000;

        // Ensure minimum premium (0.1% of cover amount)
        uint256 minPremium = (coverAmount * 10) / 10000;
        if (premium < minPremium) {
            premium = minPremium;
        }
    }

    /**
     * @notice Update premium parameters (only governor)
     */
    function updateParameters(
        uint256 _basePremiumRate,
        uint256 _riskFactorProtocol,
        uint256 _riskFactorAsset
    ) external onlyRole(GOVERNOR_ROLE) {
        require(_basePremiumRate <= 5000, "Base rate too high"); // Max 50%
        basePremiumRate = _basePremiumRate;
        riskFactorProtocol = _riskFactorProtocol;
        riskFactorAsset = _riskFactorAsset;
    }

    /**
     * @notice Update cover period limits (only governor)
     */
    function updateCoverPeriods(
        uint256 _minCoverPeriod,
        uint256 _maxCoverPeriod
    ) external onlyRole(GOVERNOR_ROLE) {
        require(_minCoverPeriod < _maxCoverPeriod, "Invalid period range");
        minCoverPeriod = _minCoverPeriod;
        maxCoverPeriod = _maxCoverPeriod;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
