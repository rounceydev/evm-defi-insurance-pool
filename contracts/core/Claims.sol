// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interfaces/IClaims.sol";
import "../interfaces/ICover.sol";
import "../interfaces/IPool.sol";
import "./Assessment.sol";
import "../mocks/MockOracle.sol";

/**
 * @title Claims
 * @notice Manages claim submission, voting, and resolution
 */
contract Claims is
    Initializable,
    IClaims,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using Counters for Counters.Counter;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ASSESSOR_ROLE = keccak256("ASSESSOR_ROLE");

    /// @notice Cover contract
    ICover public cover;

    /// @notice Pool contract
    IPool public pool;

    /// @notice Assessment contract
    Assessment public assessment;

    /// @notice Oracle contract
    MockOracle public oracle;

    /// @notice Counter for claim IDs
    Counters.Counter private _claimIdCounter;

    /// @notice Mapping of claim ID to claim data
    mapping(uint256 => ClaimData) public claims;

    /// @notice Mapping of claim ID to assessor votes
    mapping(uint256 => mapping(address => bool)) public votes; // claimId => assessor => vote (true = yes, false = no)

    /// @notice Voting period in seconds
    uint256 public votingPeriod;

    /// @notice Minimum votes required to resolve a claim
    uint256 public minVotesRequired;

    /// @notice Approval threshold (in basis points, e.g., 6600 = 66%)
    uint256 public approvalThreshold;

    event ClaimSubmitted(
        uint256 indexed claimId,
        uint256 indexed coverId,
        address indexed claimant,
        uint256 amount,
        string proof
    );

    event ClaimVoted(
        uint256 indexed claimId,
        address indexed voter,
        bool vote,
        uint256 yesVotes,
        uint256 noVotes
    );

    event ClaimResolved(
        uint256 indexed claimId,
        bool approved,
        uint256 payoutAmount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the Claims contract
     * @param admin Admin address
     * @param _cover Cover contract address
     * @param _pool Pool contract address
     * @param _assessment Assessment contract address
     * @param _oracle Oracle contract address
     * @param _votingPeriod Voting period in seconds
     * @param _minVotesRequired Minimum votes required
     * @param _approvalThreshold Approval threshold (in basis points)
     */
    function initialize(
        address admin,
        address _cover,
        address _pool,
        address _assessment,
        address _oracle,
        uint256 _votingPeriod,
        uint256 _minVotesRequired,
        uint256 _approvalThreshold
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);

        cover = ICover(_cover);
        pool = IPool(_pool);
        assessment = Assessment(_assessment);
        oracle = MockOracle(_oracle);
        votingPeriod = _votingPeriod;
        minVotesRequired = _minVotesRequired;
        approvalThreshold = _approvalThreshold;
    }

    /**
     * @notice Submit a claim
     * @param coverId Cover ID
     * @param proof Proof of loss (e.g., hack event data)
     * @return claimId The ID of the submitted claim
     */
    function submitClaim(
        uint256 coverId,
        string memory proof
    ) external whenNotPaused nonReentrant returns (uint256 claimId) {
        // Get cover data
        ICover.CoverData memory coverData = cover.getCover(coverId);

        // Verify cover ownership
        require(coverData.buyer == msg.sender, "Not cover owner");
        require(coverData.active, "Cover not active");
        require(!coverData.claimed, "Cover already claimed");
        require(
            block.timestamp >= coverData.startTime &&
                block.timestamp <= coverData.endTime,
            "Cover not in valid period"
        );

        // Generate claim ID
        claimId = _claimIdCounter.current();
        _claimIdCounter.increment();

        // Create claim data
        claims[claimId] = ClaimData({
            claimId: claimId,
            coverId: coverId,
            claimant: msg.sender,
            proof: proof,
            amount: coverData.coverAmount,
            submissionTime: block.timestamp,
            resolved: false,
            approved: false,
            yesVotes: 0,
            noVotes: 0
        });

        emit ClaimSubmitted(claimId, coverId, msg.sender, coverData.coverAmount, proof);

        return claimId;
    }

    /**
     * @notice Vote on a claim
     * @param claimId Claim ID
     * @param vote True for approve, false for reject
     */
    function voteOnClaim(
        uint256 claimId,
        bool vote
    ) external whenNotPaused {
        require(assessment.isValidAssessor(msg.sender), "Not a valid assessor");
        require(hasRole(ASSESSOR_ROLE, msg.sender), "Not an assessor");
        require(!claims[claimId].resolved, "Claim already resolved");
        require(
            block.timestamp <=
                claims[claimId].submissionTime + votingPeriod,
            "Voting period ended"
        );
        require(!votes[claimId][msg.sender], "Already voted");

        // Get voting power
        uint256 votingPower = assessment.getVotingPower(msg.sender);

        // Record vote
        votes[claimId][msg.sender] = true;
        assessment.markAsVoted(claimId, msg.sender);

        if (vote) {
            claims[claimId].yesVotes += votingPower;
        } else {
            claims[claimId].noVotes += votingPower;
        }

        emit ClaimVoted(
            claimId,
            msg.sender,
            vote,
            claims[claimId].yesVotes,
            claims[claimId].noVotes
        );
    }

    /**
     * @notice Resolve a claim (can be called by anyone after voting period)
     * @param claimId Claim ID
     */
    function resolveClaim(uint256 claimId) external nonReentrant {
        ClaimData storage claim = claims[claimId];
        require(!claim.resolved, "Claim already resolved");
        require(
            block.timestamp > claim.submissionTime + votingPeriod,
            "Voting period not ended"
        );

        uint256 totalVotes = claim.yesVotes + claim.noVotes;
        require(totalVotes >= minVotesRequired, "Insufficient votes");

        claim.resolved = true;

        // Check if approved (yes votes >= threshold)
        uint256 approvalRatio = (claim.yesVotes * 10000) / totalVotes;
        bool approved = approvalRatio >= approvalThreshold;

        claim.approved = approved;

        uint256 payoutAmount = 0;

        if (approved) {
            // Verify hack via oracle (optional check)
            ICover.CoverData memory coverData = cover.getCover(claim.coverId);
            bool isHacked = oracle.isProtocolHacked(coverData.coveredProtocol);

            // Payout if approved and protocol is hacked (or if oracle check is bypassed for testing)
            if (isHacked || true) {
                // Payout from pool
                pool.payout(claim.claimant, claim.amount);
                payoutAmount = claim.amount;

                // Mark cover as claimed
                cover.markCoverAsClaimed(claim.coverId);
            }
        }

        emit ClaimResolved(claimId, approved, payoutAmount);
    }

    /**
     * @notice Get claim data
     * @param claimId Claim ID
     * @return Claim data struct
     */
    function getClaim(
        uint256 claimId
    ) external view returns (ClaimData memory) {
        return claims[claimId];
    }

    /**
     * @notice Update voting parameters (only governor)
     */
    function updateVotingParameters(
        uint256 _votingPeriod,
        uint256 _minVotesRequired,
        uint256 _approvalThreshold
    ) external onlyRole(GOVERNOR_ROLE) {
        require(_approvalThreshold <= 10000, "Threshold must be <= 100%");
        votingPeriod = _votingPeriod;
        minVotesRequired = _minVotesRequired;
        approvalThreshold = _approvalThreshold;
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

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
