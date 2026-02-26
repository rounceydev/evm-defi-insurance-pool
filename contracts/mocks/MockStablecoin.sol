// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockStablecoin
 * @notice Mock ERC-20 stablecoin for testing purposes
 */
contract MockStablecoin is ERC20 {
    constructor() ERC20("Mock USD Coin", "MUSDC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6; // USDC-like decimals
    }
}
