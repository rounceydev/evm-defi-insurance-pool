// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IClaims
 * @notice Interface for the Claims contract
 */
interface IClaims {
    struct ClaimData {
        uint256 claimId;
        uint256 coverId;
        address claimant;
        string proof; // Proof of loss (e.g., hack event data)
        uint256 amount; // Claim amount
        uint256 submissionTime;
        bool resolved; // Whether claim has been resolved
        bool approved; // Whether claim was approved
        uint256 yesVotes;
        uint256 noVotes;
    }

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

    function submitClaim(
        uint256 coverId,
        string memory proof
    ) external returns (uint256 claimId);

    function voteOnClaim(uint256 claimId, bool vote) external;

    function resolveClaim(uint256 claimId) external;

    function getClaim(
        uint256 claimId
    ) external view returns (ClaimData memory);
}
