// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GovernanceToken
 * @notice ERC-20 governance token with voting power and staking capabilities
 * @dev Inspired by Nexus Mutual's NXM token
 */
contract GovernanceToken is
    Initializable,
    ERC20Upgradeable,
    ERC20VotesUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Mapping of staked amounts per user
    mapping(address => uint256) public stakedBalance;

    /// @notice Mapping of locked stakes (timestamp when lock expires)
    mapping(address => uint256) public stakeLockExpiry;

    /// @notice Total staked amount
    uint256 public totalStaked;

    event TokensStaked(address indexed user, uint256 amount, uint256 lockUntil);
    event TokensUnstaked(address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the governance token
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial token supply
     * @param admin Admin address
     */
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address admin
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Votes_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);

        if (initialSupply > 0) {
            _mint(admin, initialSupply);
        }
    }

    /**
     * @notice Stake tokens to become an assessor
     * @param amount Amount of tokens to stake
     * @param lockPeriod Lock period in seconds
     */
    function stake(uint256 amount, uint256 lockPeriod) external {
        require(amount > 0, "Amount must be greater than 0");
        require(
            balanceOf(msg.sender) >= amount,
            "Insufficient balance to stake"
        );

        _transfer(msg.sender, address(this), amount);

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        uint256 lockUntil = block.timestamp + lockPeriod;
        if (stakeLockExpiry[msg.sender] < lockUntil) {
            stakeLockExpiry[msg.sender] = lockUntil;
        }

        emit TokensStaked(msg.sender, amount, lockUntil);
    }

    /**
     * @notice Unstake tokens (only after lock period expires)
     * @param amount Amount of tokens to unstake
     */
    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(
            stakedBalance[msg.sender] >= amount,
            "Insufficient staked balance"
        );
        require(
            block.timestamp >= stakeLockExpiry[msg.sender],
            "Stake is still locked"
        );

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        _transfer(address(this), msg.sender, amount);

        emit TokensUnstaked(msg.sender, amount);
    }

    /**
     * @notice Get voting power for an address (staked + held tokens)
     * @param account Address to check
     * @return Voting power
     */
    function getVotingPower(
        address account
    ) external view returns (uint256) {
        return balanceOf(account) + stakedBalance[account];
    }

    /**
     * @notice Mint new tokens (only for minter role)
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    // Override required by Solidity
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
