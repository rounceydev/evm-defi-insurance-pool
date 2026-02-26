// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IQuotation
 * @notice Interface for premium quotation calculations
 */
interface IQuotation {
    function calculatePremium(
        uint256 coverAmount,
        uint256 coverPeriod,
        address coveredProtocol
    ) external view returns (uint256 premium);
}
