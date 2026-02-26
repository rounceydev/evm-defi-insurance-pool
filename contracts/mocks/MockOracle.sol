// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockOracle
 * @notice Mock oracle for protocol hack detection and risk assessment
 */
contract MockOracle {
    mapping(address => bool) public protocolHacked;
    mapping(address => uint256) public riskScore; // 0-10000 (0-100%)

    event ProtocolHackDetected(address indexed protocol, uint256 timestamp);
    event RiskScoreUpdated(address indexed protocol, uint256 newScore);

    constructor() {
        // Initialize with default risk scores
        riskScore[address(0)] = 500; // 5% default risk
    }

    /**
     * @notice Set a protocol as hacked (for testing)
     */
    function setProtocolHacked(address protocol, bool hacked) external {
        protocolHacked[protocol] = hacked;
        if (hacked) {
            emit ProtocolHackDetected(protocol, block.timestamp);
        }
    }

    /**
     * @notice Set risk score for a protocol
     */
    function setRiskScore(address protocol, uint256 score) external {
        require(score <= 10000, "Risk score must be <= 100%");
        riskScore[protocol] = score;
        emit RiskScoreUpdated(protocol, score);
    }

    /**
     * @notice Check if a protocol has been hacked
     */
    function isProtocolHacked(address protocol) external view returns (bool) {
        return protocolHacked[protocol];
    }

    /**
     * @notice Get risk score for a protocol
     */
    function getRiskScore(address protocol) external view returns (uint256) {
        return riskScore[protocol] > 0 ? riskScore[protocol] : 500; // Default 5%
    }
}
