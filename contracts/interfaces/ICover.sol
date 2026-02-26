// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICover
 * @notice Interface for the Cover contract
 */
interface ICover {
    struct CoverData {
        uint256 coverId;
        address buyer;
        address coveredProtocol; // Protocol or asset address being covered
        uint256 coverAmount; // Amount covered in ETH/stablecoin
        uint256 premium; // Premium paid
        uint256 startTime; // Cover start timestamp
        uint256 endTime; // Cover end timestamp
        bool active; // Whether cover is still active
        bool claimed; // Whether a claim has been made
    }

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

    function purchaseCover(
        address coveredProtocol,
        uint256 coverAmount,
        uint256 coverPeriod
    ) external payable returns (uint256 coverId);

    function getCover(uint256 coverId) external view returns (CoverData memory);

    function isCoverActive(uint256 coverId) external view returns (bool);
}
