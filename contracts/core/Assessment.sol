// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../tokens/GovernanceToken.sol";

/**
 * @title Assessment
 * @notice Manages assessor staking and voting on claims
 */
contract Assessment is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ASSESSOR_ROLE = keccak256("ASSESSOR_ROLE");

    /// @notice Governance token contract
    GovernanceToken public governanceToken;

    /// @notice Minimum stake required to become an assessor
    uint256 public minStakeAmount;

    /// @notice Mapping of assessor addresses
    mapping(address => bool) public assessors;

    /// @notice Mapping of claim ID to assessor votes
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event AssessorRegistered(address indexed assessor);
    event AssessorRemoved(address indexed assessor);
    event MinStakeUpdated(uint256 newMinStake);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the Assessment contract
     * @param admin Admin address
     * @param _governanceToken Governance token address
     * @param _minStakeAmount Minimum stake amount
     */
    function initialize(
        address admin,
        address _governanceToken,
        uint256 _minStakeAmount
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);

        governanceToken = GovernanceToken(_governanceToken);
        minStakeAmount = _minStakeAmount;
    }

    /**
     * @notice Register as an assessor by staking tokens
     * @param stakeAmount Amount to stake
     * @param lockPeriod Lock period in seconds
     */
    function registerAsAssessor(
        uint256 stakeAmount,
        uint256 lockPeriod
    ) external whenNotPaused {
        require(stakeAmount >= minStakeAmount, "Stake below minimum");
        require(!assessors[msg.sender], "Already registered as assessor");

        // Stake tokens
        governanceToken.stake(stakeAmount, lockPeriod);

        // Register as assessor
        assessors[msg.sender] = true;
        _grantRole(ASSESSOR_ROLE, msg.sender);

        emit AssessorRegistered(msg.sender);
    }

    /**
     * @notice Remove assessor status (if stake falls below minimum)
     * @param assessor Address to remove
     */
    function removeAssessor(address assessor) external {
        require(
            governanceToken.stakedBalance(assessor) < minStakeAmount,
            "Stake still above minimum"
        );
        require(assessors[assessor], "Not an assessor");

        assessors[assessor] = false;
        _revokeRole(ASSESSOR_ROLE, assessor);

        emit AssessorRemoved(assessor);
    }

    /**
     * @notice Check if address is a valid assessor
     * @param assessor Address to check
     * @return Whether address is a valid assessor
     */
    function isValidAssessor(address assessor) external view returns (bool) {
        return
            assessors[assessor] &&
            governanceToken.stakedBalance(assessor) >= minStakeAmount;
    }

    /**
     * @notice Get voting power for an assessor
     * @param assessor Assessor address
     * @return Voting power (staked amount)
     */
    function getVotingPower(address assessor) external view returns (uint256) {
        return governanceToken.stakedBalance(assessor);
    }

    /**
     * @notice Check if assessor has voted on a claim
     * @param claimId Claim ID
     * @param assessor Assessor address
     * @return Whether assessor has voted
     */
    function hasAssessorVoted(
        uint256 claimId,
        address assessor
    ) external view returns (bool) {
        return hasVoted[claimId][assessor];
    }

    /**
     * @notice Mark assessor as having voted (called by Claims contract)
     * @param claimId Claim ID
     * @param assessor Assessor address
     */
    function markAsVoted(
        uint256 claimId,
        address assessor
    ) external onlyRole(GOVERNOR_ROLE) {
        hasVoted[claimId][assessor] = true;
    }

    /**
     * @notice Update minimum stake amount (only governor)
     */
    function updateMinStake(uint256 _minStakeAmount) external onlyRole(GOVERNOR_ROLE) {
        minStakeAmount = _minStakeAmount;
        emit MinStakeUpdated(_minStakeAmount);
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
