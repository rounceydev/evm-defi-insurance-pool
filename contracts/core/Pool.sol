// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IPool.sol";

/**
 * @title Pool
 * @notice Manages the insurance pool capital (ETH and stablecoins)
 * @dev Handles deposits, withdrawals, and payouts while maintaining solvency
 */
contract Pool is
    Initializable,
    IPool,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant PAYOUT_ROLE = keccak256("PAYOUT_ROLE");

    /// @notice Total capital in the pool (ETH)
    uint256 public totalCapital;

    /// @notice Total outstanding cover liabilities
    uint256 public totalLiabilities;

    /// @notice Minimum capital ratio (in basis points, e.g., 15000 = 150%)
    uint256 public minCapitalRatio;

    /// @notice Minimum pool capital required
    uint256 public minPoolCapital;

    /// @notice Accepted stablecoin for deposits
    IERC20 public acceptedStablecoin;

    /// @notice Stablecoin balance in pool
    uint256 public stablecoinBalance;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Payout(address indexed recipient, uint256 amount);
    event LiabilitiesUpdated(uint256 newLiabilities);
    event ParametersUpdated(uint256 minCapitalRatio, uint256 minPoolCapital);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the Pool contract
     * @param admin Admin address
     * @param _acceptedStablecoin Address of accepted stablecoin
     * @param _minCapitalRatio Minimum capital ratio (in basis points)
     * @param _minPoolCapital Minimum pool capital
     */
    function initialize(
        address admin,
        address _acceptedStablecoin,
        uint256 _minCapitalRatio,
        uint256 _minPoolCapital
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
        _grantRole(PAYOUT_ROLE, admin);

        acceptedStablecoin = IERC20(_acceptedStablecoin);
        minCapitalRatio = _minCapitalRatio;
        minPoolCapital = _minPoolCapital;
    }

    /**
     * @notice Deposit ETH to the pool
     */
    function deposit() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Must deposit more than 0");
        totalCapital += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Deposit stablecoin to the pool
     * @param amount Amount of stablecoin to deposit
     */
    function depositStablecoin(
        uint256 amount
    ) external whenNotPaused nonReentrant {
        require(amount > 0, "Must deposit more than 0");
        acceptedStablecoin.safeTransferFrom(msg.sender, address(this), amount);
        stablecoinBalance += amount;
        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw ETH from the pool (only governor)
     * @param amount Amount to withdraw
     */
    function withdraw(
        uint256 amount
    ) external onlyRole(GOVERNOR_ROLE) nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= totalCapital, "Insufficient capital");
        require(
            checkSolvencyAfterWithdrawal(amount),
            "Withdrawal would violate solvency requirements"
        );

        totalCapital -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Payout claim from the pool
     * @param recipient Address to receive the payout
     * @param amount Amount to payout
     */
    function payout(
        address recipient,
        uint256 amount
    ) external onlyRole(PAYOUT_ROLE) nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(recipient != address(0), "Invalid recipient");

        // Try ETH first, then stablecoin
        if (amount <= totalCapital) {
            totalCapital -= amount;
            payable(recipient).transfer(amount);
        } else if (amount <= stablecoinBalance) {
            stablecoinBalance -= amount;
            acceptedStablecoin.safeTransfer(recipient, amount);
        } else {
            revert("Insufficient pool funds");
        }

        emit Payout(recipient, amount);
    }

    /**
     * @notice Update total liabilities (called by Cover contract)
     * @param newLiabilities New total liabilities
     */
    function updateLiabilities(
        uint256 newLiabilities
    ) external onlyRole(PAYOUT_ROLE) {
        totalLiabilities = newLiabilities;
        emit LiabilitiesUpdated(newLiabilities);
    }

    /**
     * @notice Get total capital (ETH + stablecoin value)
     */
    function getTotalCapital() external view returns (uint256) {
        return totalCapital + stablecoinBalance;
    }

    /**
     * @notice Get available capital for new covers
     */
    function getAvailableCapital() external view returns (uint256) {
        uint256 total = totalCapital + stablecoinBalance;
        uint256 required = (totalLiabilities * minCapitalRatio) / 10000;
        if (total > required) {
            return total - required;
        }
        return 0;
    }

    /**
     * @notice Get solvency ratio (capital / liabilities * 10000)
     */
    function getSolvencyRatio() external view returns (uint256) {
        if (totalLiabilities == 0) {
            return type(uint256).max; // Infinite ratio if no liabilities
        }
        uint256 total = totalCapital + stablecoinBalance;
        return (total * 10000) / totalLiabilities;
    }

    /**
     * @notice Check if pool is solvent
     */
    function isSolvent() external view returns (bool) {
        uint256 total = totalCapital + stablecoinBalance;
        uint256 required = (totalLiabilities * minCapitalRatio) / 10000;
        return total >= required && total >= minPoolCapital;
    }

    /**
     * @notice Check solvency after a withdrawal
     */
    function checkSolvencyAfterWithdrawal(
        uint256 withdrawalAmount
    ) internal view returns (bool) {
        uint256 total = totalCapital + stablecoinBalance;
        uint256 afterWithdrawal = total - withdrawalAmount;
        uint256 required = (totalLiabilities * minCapitalRatio) / 10000;
        return afterWithdrawal >= required && afterWithdrawal >= minPoolCapital;
    }

    /**
     * @notice Update pool parameters (only governor)
     */
    function updateParameters(
        uint256 _minCapitalRatio,
        uint256 _minPoolCapital
    ) external onlyRole(GOVERNOR_ROLE) {
        require(_minCapitalRatio >= 10000, "Capital ratio must be at least 100%");
        minCapitalRatio = _minCapitalRatio;
        minPoolCapital = _minPoolCapital;
        emit ParametersUpdated(_minCapitalRatio, _minPoolCapital);
    }

    /**
     * @notice Pause the contract (only governor)
     */
    function pause() external onlyRole(GOVERNOR_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract (only governor)
     */
    function unpause() external onlyRole(GOVERNOR_ROLE) {
        _unpause();
    }

    /**
     * @notice Receive ETH
     */
    receive() external payable {
        deposit();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
