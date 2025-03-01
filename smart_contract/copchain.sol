// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BikeNFT is ERC721URIStorage, AccessControl {
    using SafeMath for uint256;

    // Roles for authorized issuers
    bytes32 public constant POLICE_ROLE = keccak256("POLICE_ROLE");
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");

    // Police wallet for transaction fees
    address payable public policeWallet;

    // Mapping of token ID to pending claims (buyers who purchased a bike)
    mapping(uint256 => address) public pendingClaims;

    // Mapping for storing additional metadata (Bike ID, Owner ID, Contact Info)
    struct BikeMetadata {
        string bikeId;
        string ownerId;
        string contactInfo;
    }
    mapping(uint256 => BikeMetadata) public bikeMetadata;

    constructor(address payable _policeWallet) ERC721("BikeNFT", "BIKE") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(POLICE_ROLE, msg.sender);
        policeWallet = _policeWallet;
    }

    /// @notice Mint a new Bike NFT (only Police or Seller)
    function mintBikeNFT(
        uint256 _tokenId,
        string memory _tokenURI,
        string memory _bikeId,
        string memory _ownerId,
        string memory _contactInfo,
        address _buyer // Buyer who will claim the NFT
    ) public onlyRole(POLICE_ROLE) onlyRole(SELLER_ROLE) {
        _mint(address(this), _tokenId); // Mint to contract first
        _setTokenURI(_tokenId, _tokenURI);
        pendingClaims[_tokenId] = _buyer; // Mark NFT as claimable

        // Store metadata
        bikeMetadata[_tokenId] = BikeMetadata(_bikeId, _ownerId, _contactInfo);
    }

    /// @notice Claim NFT after purchasing a physical bike
    function claimBike(uint256 _tokenId) public {
        require(pendingClaims[_tokenId] == msg.sender, "Not authorized to claim");
        _transfer(address(this), msg.sender, _tokenId);
        pendingClaims[_tokenId] = address(0); // Remove claim
    }

    /// @notice Buy and transfer NFT ownership (1% fee to police)
    function buyBike(uint256 _tokenId, string memory _newOwnerId, string memory _newContactInfo) public payable {
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

        // Update metadata with new owner details
        bikeMetadata[_tokenId].ownerId = _newOwnerId;
        bikeMetadata[_tokenId].contactInfo = _newContactInfo;
    }

    /// @notice Update contact information of the owner
    function updateContactInfo(uint256 _tokenId, string memory _newContactInfo) public {
        require(ownerOf(_tokenId) == msg.sender, "Only owner can update contact info");
        bikeMetadata[_tokenId].contactInfo = _newContactInfo;
    }

    /// @notice Set a new police wallet (only admin)
    function setPoliceWallet(address payable _newWallet) public onlyRole(DEFAULT_ADMIN_ROLE) {
        policeWallet = _newWallet;
    }

    /// @notice Fetch metadata for a given Bike NFT
    function getBikeMetadata(uint256 _tokenId) public view returns (string memory, string memory, string memory) {
        BikeMetadata memory metadata = bikeMetadata[_tokenId];
        return (metadata.bikeId, metadata.ownerId, metadata.contactInfo);
    }
}
