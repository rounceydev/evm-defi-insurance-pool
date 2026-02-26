// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPool
 * @notice Interface for the Pool contract
 */
interface IPool {
    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Payout(address indexed recipient, uint256 amount);

    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function payout(address recipient, uint256 amount) external;

    function getTotalCapital() external view returns (uint256);

    function getAvailableCapital() external view returns (uint256);

    function getSolvencyRatio() external view returns (uint256);
}
