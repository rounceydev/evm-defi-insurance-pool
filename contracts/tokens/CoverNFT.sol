// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title CoverNFT
 * @notice ERC-721 NFT representing insurance cover policies
 */
contract CoverNFT is ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => string) private _coverMetadata;

    constructor() ERC721("Insurance Cover", "COVER") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @notice Mint a new cover NFT
     * @param to Address to mint the NFT to
     * @param tokenURI Metadata URI for the cover
     * @return tokenId The minted token ID
     */
    function mint(
        address to,
        string memory tokenURI
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return tokenId;
    }

    /**
     * @notice Burn a cover NFT
     * @param tokenId The token ID to burn
     */
    function burn(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    /**
     * @notice Set metadata for a cover
     */
    function setCoverMetadata(
        uint256 tokenId,
        string memory metadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _coverMetadata[tokenId] = metadata;
    }

    /**
     * @notice Get metadata for a cover
     */
    function getCoverMetadata(
        uint256 tokenId
    ) external view returns (string memory) {
        return _coverMetadata[tokenId];
    }

    // The following functions are overrides required by Solidity.

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
