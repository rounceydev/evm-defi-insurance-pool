// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/ICover.sol";
import "../interfaces/IPool.sol";
import "../interfaces/IQuotation.sol";
import "../tokens/CoverNFT.sol";

/**
 * @title Cover
 * @notice Manages insurance cover purchases and minting of cover NFTs
 */
contract Cover is
    Initializable,
    ICover,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using Counters for Counters.Counter;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @notice Cover NFT contract
    CoverNFT public coverNFT;

    /// @notice Pool contract
    IPool public pool;

    /// @notice Quotation contract
    IQuotation public quotation;

    /// @notice Counter for cover IDs
    Counters.Counter private _coverIdCounter;

    /// @notice Mapping of cover ID to cover data
    mapping(uint256 => CoverData) public covers;

    /// @notice Minimum cover amount
    uint256 public minCoverAmount;

    /// @notice Maximum cover amount
    uint256 public maxCoverAmount;

    /// @notice Total active cover amount
    uint256 public totalActiveCoverAmount;

    event CoverPurchased(
        uint256 indexed coverId,
        address indexed buyer,
        address indexed coveredProtocol,
        uint256 coverAmount,
        uint256 premium,
        uint256 startTime,
        uint256 endTime
    );

    event CoverExpired(uint256 indexed coverId);
    event CoverClaimed(uint256 indexed coverId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the Cover contract
     * @param admin Admin address
     * @param _coverNFT Cover NFT contract address
     * @param _pool Pool contract address
     * @param _quotation Quotation contract address
     * @param _minCoverAmount Minimum cover amount
     * @param _maxCoverAmount Maximum cover amount
     */
    function initialize(
        address admin,
        address _coverNFT,
        address _pool,
        address _quotation,
        uint256 _minCoverAmount,
        uint256 _maxCoverAmount
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);

        coverNFT = CoverNFT(_coverNFT);
        pool = IPool(_pool);
        quotation = IQuotation(_quotation);
        minCoverAmount = _minCoverAmount;
        maxCoverAmount = _maxCoverAmount;
    }

    /**
     * @notice Purchase a cover
     * @param coveredProtocol Protocol or asset address being covered
     * @param coverAmount Amount to cover
     * @param coverPeriod Cover period in seconds
     * @return coverId The ID of the purchased cover
     */
    function purchaseCover(
        address coveredProtocol,
        uint256 coverAmount,
        uint256 coverPeriod
    ) external payable whenNotPaused nonReentrant returns (uint256 coverId) {
        require(coverAmount >= minCoverAmount, "Cover amount too low");
        require(coverAmount <= maxCoverAmount, "Cover amount too high");
        require(coveredProtocol != address(0), "Invalid protocol address");

        // Calculate premium
        uint256 premium = quotation.calculatePremium(
            coverAmount,
            coverPeriod,
            coveredProtocol
        );

        require(msg.value >= premium, "Insufficient premium payment");

        // Check pool solvency
        require(
            pool.isSolvent(),
            "Pool is not solvent, cannot issue new covers"
        );

        // Check available capital
        uint256 availableCapital = pool.getAvailableCapital();
        require(
            availableCapital >= coverAmount,
            "Insufficient pool capital for cover"
        );

        // Generate cover ID
        coverId = _coverIdCounter.current();
        _coverIdCounter.increment();

        // Create cover data
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + coverPeriod;

        covers[coverId] = CoverData({
            coverId: coverId,
            buyer: msg.sender,
            coveredProtocol: coveredProtocol,
            coverAmount: coverAmount,
            premium: premium,
            startTime: startTime,
            endTime: endTime,
            active: true,
            claimed: false
        });

        // Update total active cover
        totalActiveCoverAmount += coverAmount;

        // Update pool liabilities
        pool.updateLiabilities(totalActiveCoverAmount);

        // Mint NFT
        string memory tokenURI = string(
            abi.encodePacked(
                "https://insurance.example.com/covers/",
                _toString(coverId)
            )
        );
        coverNFT.mint(msg.sender, tokenURI);

        // Deposit premium to pool
        pool.deposit{value: premium}();

        // Refund excess payment
        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }

        emit CoverPurchased(
            coverId,
            msg.sender,
            coveredProtocol,
            coverAmount,
            premium,
            startTime,
            endTime
        );

        return coverId;
    }

    /**
     * @notice Get cover data
     * @param coverId Cover ID
     * @return Cover data struct
     */
    function getCover(
        uint256 coverId
    ) external view returns (CoverData memory) {
        return covers[coverId];
    }

    /**
     * @notice Check if cover is active
     * @param coverId Cover ID
     * @return Whether cover is active
     */
    function isCoverActive(uint256 coverId) external view returns (bool) {
        CoverData memory cover = covers[coverId];
        return
            cover.active &&
            !cover.claimed &&
            block.timestamp >= cover.startTime &&
            block.timestamp <= cover.endTime;
    }

    /**
     * @notice Expire a cover (called when cover period ends)
     * @param coverId Cover ID
     */
    function expireCover(uint256 coverId) external {
        CoverData storage cover = covers[coverId];
        require(cover.active, "Cover not active");
        require(block.timestamp > cover.endTime, "Cover not expired yet");

        cover.active = false;
        totalActiveCoverAmount -= cover.coverAmount;
        pool.updateLiabilities(totalActiveCoverAmount);

        emit CoverExpired(coverId);
    }

    /**
     * @notice Mark cover as claimed (called by Claims contract)
     * @param coverId Cover ID
     */
    function markCoverAsClaimed(
        uint256 coverId
    ) external onlyRole(GOVERNOR_ROLE) {
        CoverData storage cover = covers[coverId];
        require(cover.active, "Cover not active");
        require(!cover.claimed, "Cover already claimed");

        cover.claimed = true;
        cover.active = false;
        totalActiveCoverAmount -= cover.coverAmount;
        pool.updateLiabilities(totalActiveCoverAmount);

        emit CoverClaimed(coverId);
    }

    /**
     * @notice Update cover limits (only governor)
     */
    function updateCoverLimits(
        uint256 _minCoverAmount,
        uint256 _maxCoverAmount
    ) external onlyRole(GOVERNOR_ROLE) {
        require(_minCoverAmount < _maxCoverAmount, "Invalid limits");
        minCoverAmount = _minCoverAmount;
        maxCoverAmount = _maxCoverAmount;
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
     * @notice Convert uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
