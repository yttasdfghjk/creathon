// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BikeNFT is ERC721URIStorage, AccessControl {
    using SafeMath for uint256;

    // Roles for authorized minters
    bytes32 public constant POLICE_ROLE = keccak256("POLICE_ROLE");
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");

    // Police wallet to receive transaction fees
    address payable public policeWallet;

    // Mapping from token ID to pending claims
    mapping(uint256 => address) public pendingClaims;

    constructor(address payable _policeWallet) ERC721("BikeNFT", "BIKE") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(POLICE_ROLE, msg.sender);
        policeWallet = _policeWallet;
    }

    /// @notice Mint a new Bike NFT (only Police or Seller)
    function mintBikeNFT(
        address _to,
        uint256 _tokenId,
        string memory _tokenURI
    ) public onlyRole(POLICE_ROLE) onlyRole(SELLER_ROLE) {
        _mint(address(this), _tokenId); // Mint to contract first
        _setTokenURI(_tokenId, _tokenURI);
        pendingClaims[_tokenId] = _to; // Mark NFT as claimable
    }

    /// @notice Claim NFT after physical bike purchase
    function claimBike(uint256 _tokenId) public {
        require(pendingClaims[_tokenId] == msg.sender, "Not authorized to claim");
        _transfer(address(this), msg.sender, _tokenId);
        pendingClaims[_tokenId] = address(0); // Remove claim
    }

    /// @notice Buy and transfer NFT ownership (1% fee to police)
    function buyBike(uint256 _tokenId) public payable {
        address currentOwner = ownerOf(_tokenId);
        require(currentOwner != address(0), "NFT does not exist");
        require(msg.sender != currentOwner, "Cannot buy your own NFT");

        // Calculate 1% fee
        uint256 fee = msg.value.div(100); // 1% of transaction value
        uint256 sellerAmount = msg.value.sub(fee);

        // Transfer funds
        policeWallet.transfer(fee);
        payable(currentOwner).transfer(sellerAmount);

        // Transfer NFT ownership
        _transfer(currentOwner, msg.sender, _tokenId);
    }

    /// @notice Set a new police wallet (only admin)
    function setPoliceWallet(address payable _newWallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        policeWallet = _newWallet;
    }
}

