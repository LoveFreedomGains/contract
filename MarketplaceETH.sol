// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";



interface IERC721Royalty is IERC721 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
}

contract FreedomForgeEETH is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _nftsSold;
    Counters.Counter private _nftCount;
    address payable private _marketOwner;
    mapping(uint256 => NFT) private _idToNFT;
    mapping(uint256 => NftDetails) private _nftDetails;
    IERC20 public requiredToken; 
    uint256 public requiredTokenAmount; 
    mapping(uint256 => address) private _owners;
    uint256 public marketplaceFee = 0.01 * 10**18; // 0.01 BNB in wei
    mapping(address => bool) public approvedSigners; 
    uint256 private _listingIdCounter; 

    // EIP-712 Domain Separator
    bytes32 private immutable _DOMAIN_SEPARATOR;

// EIP-712 Typed Data Struct
    struct NFTApproval {
        address signer;
        address nftContract;
        uint256 tokenId;

    }

  mapping(uint256 => Listing) public listings; // Listing ID -> Listing  
    
struct Listing {
    address payable seller;
    address nftContract;
    uint256 tokenId;
    uint256 price;
    bool listed;
    uint256 listingId; 
}

struct NFT {
    address payable seller;
    address nftContract;
    uint256 tokenId;
    uint256 price;
    bool listed;
    uint256 listingId; 
}
    struct NftDetails {
        string name;
        string description;
        string imageUri;
    }

    event SignatureRequested(address indexed signer, address indexed nftContract, uint256 indexed tokenId);
    event LogMessage(string message, address valueAddress, uint256 valueUint);
    event SignerApprovalRequired(address indexed signer);
   event ListingCreated(uint256 indexed tokenId, address indexed nftContract, address indexed seller, uint256 price, uint256 listingId);
    event ApprovalRequest(address indexed signer);
    event DebugLog(string message, uint256 value);
    event NFTPurchased(uint256 indexed tokenId, address indexed nftContract, address indexed buyer, uint256 price);
    event ListingFound(uint256 indexed tokenId); 
    event DebugLogBytes32(string message, bytes32 value);
    event DebugLogs(string message, string valueString); 

      constructor(address _RequiredToken, address initialOwner) 
             Ownable(initialOwner)payable  {  // Pass initialOwner to Ownable constructor
        requiredToken = IERC20(_RequiredToken); 
        requiredTokenAmount = 420000; 
        _marketOwner = payable(msg.sender);
        _DOMAIN_SEPARATOR = keccak256(abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("FreedomForgeE")), // Update with the chosen name
        keccak256(bytes("1")), // Adjust version if needed
        block.chainid,
        address(this)
    ));
    }

    function setRequiredTokenAmount(uint256 _newAmount) external onlyOwner {
    requiredTokenAmount = _newAmount;
    }



function listNft(address _contractAddress, uint256 _tokenId, uint256 _price, bytes memory _signature) public payable {
    require(_price > 0, "Price must be at least 1 wei");

    IERC721 nft = IERC721(_contractAddress);
    require(nft.ownerOf(_tokenId) == msg.sender, "Not the NFT owner");
    emit DebugLog("Token ID", _tokenId); 
    emit DebugLog("Price", _price);

    // Check if signer is approved (replace with your signer logic)
    // Signature Request Logic (Replace this with your specific implementation)
    if (!isSignatureValid(msg.sender, getHash(msg.sender, _contractAddress, _tokenId), _signature)) { 
        requestSignature(msg.sender, _contractAddress, _tokenId); 
        emit SignatureRequested(msg.sender, _contractAddress, _tokenId);
        return;  // Exit, waiting for signature
    } 

    require(nft.getApproved(_tokenId) == address(this), "NFT not approved for marketplace transfer");

    require(requiredToken.balanceOf(msg.sender) >= requiredTokenAmount, "Insufficient token balance");
    emit DebugLog("msg.value", msg.value); 
    require(msg.value == marketplaceFee, "listing fee Error"); 

    // Transfer marketplace fee
    _marketOwner.transfer(marketplaceFee);

    
    // Update listing details
    uint256 listingId = _listingIdCounter;
    listings[listingId] = Listing(
    payable(msg.sender),
    _contractAddress,
    _tokenId,
    _price,
    true,
    listingId
    );
    _listingIdCounter++; // Increment after using the current value
    emit DebugLogs("NFT Struct (seller) BEFORE update:", string(abi.encodePacked(_idToNFT[_tokenId].seller))); 
    emit DebugLog("NFT Struct (listingId) BEFORE update:", _idToNFT[_tokenId].listingId); 
// Assuming the 'listingId' field is of type 'uint256'
   emit DebugLog("Listing ID before update", listingId); 
    listings[listingId] = Listing(payable(msg.sender), _contractAddress, _tokenId, _price, true, listingId);
    emit DebugLog("Listing ID after update", listingId);
    // Update NFT struct (use listingId)
    _idToNFT[_tokenId].listed = true;
    _idToNFT[_tokenId].listingId = listingId; 

    _nftCount.increment(); 

    // Emit event 
    emit ListingCreated(_tokenId, _contractAddress, msg.sender, _price, listingId); 
    emit DebugLogs("NFT Struct (seller) AFTER update:", string(abi.encodePacked(_idToNFT[_tokenId].seller))); 
    emit DebugLog("NFT Struct (price) AFTER update:", _idToNFT[_tokenId].price); 
    emit DebugLog("nftCount after listing", _nftCount.current()); // Example output: 1
}




    // Buy an NFT
function buyNFT(address _nftContract, uint256 _tokenId) public payable {
    // Look up listing based on NFT's token ID
    (uint256 listingId, bool isListed) = findListingIdByTokenId(_tokenId);
    require(isListed, "NFT not listed"); // Ensure the NFT is indeed listed

    // Retrieve the listing
    Listing storage listing = listings[listingId]; 

    // 1. Payment Validation:
    require(listing.price == msg.value, "Incorrect price");

    // 2. Ownership Check:
    require(listing.seller != msg.sender, "Cannot buy your own NFT");

    // 3. Token Balance Check:
    require(requiredToken.balanceOf(msg.sender) >= requiredTokenAmount, "Insufficient token balance"); 

    // 4. Availability Check:
    require(_idToNFT[listingId].listed, "NFT no longer available"); 

    // 5. NFT Contract Interaction:
    IERC721 nft = IERC721(_nftContract);
    require(nft.getApproved(_tokenId) == address(this), "NFT not approved for marketplace transfer");

    // 6. Facilitate Direct Transfer (Seller to Buyer):
    nft.safeTransferFrom(listing.seller, msg.sender, _tokenId); 

    // 7. Payment Distribution:
    (bool success, ) = payable(listing.seller).call{value: msg.value - marketplaceFee}(""); 
    require(success, "Payment transfer to seller failed");

    // 8. Marketplace Fee (Optional):
    if (marketplaceFee > 0) {
        _marketOwner.transfer(marketplaceFee);
    }

    // 9. Mark as Sold:
    _idToNFT[listingId].listed = false; 

    // 10. Cleanup:
    delete listings[listingId]; 

    // 11. Event Emission:
    emit NFTPurchased(_tokenId, listing.nftContract, msg.sender, listing.price); 
}




function getListedNfts() public view returns (NFT[] memory) {
    uint256 listedNftCount = 0;

    // Count listed NFTs
    for (uint256 i = 0; i < _listingIdCounter; i++) {
        if (listings[i].listed) { // Check if listed (open to all)
            listedNftCount++; 
        }
    }

    // Create array of the correct size
    NFT[] memory nfts = new NFT[](listedNftCount);
    uint256 nftsIndex = 0;

    // Populate the array directly
    for (uint256 i = 0; i < _listingIdCounter; i++) {
    if (listings[i].listed) {
        NFT memory nft = NFT(
            listings[i].seller,         // seller
            listings[i].nftContract,    // nftContract
            listings[i].tokenId,        // tokenId
            listings[i].price,          // price
            listings[i].listed,         // listed 
            listings[i].listingId       // listingId
        );
        nfts[nftsIndex] = nft;
        nftsIndex++;
    }
}

    return nfts;
}

function getMyListedNfts() public view returns (NFT[] memory) {
    uint256 myListedNftCount = 0;
    for (uint256 listingId = 0; listingId < _listingIdCounter; listingId++) {
        Listing memory listing = listings[listingId];
        if (listing.listed && listing.seller == msg.sender) { 
            myListedNftCount++; 
        }
    }

    NFT[] memory nfts = new NFT[](myListedNftCount);
    uint256 nftsIndex = 0;

    for (uint256 listingId = 0; listingId < _listingIdCounter; listingId++) {
        Listing memory listing = listings[listingId];
        if (listing.listed && listing.seller == msg.sender) {
            NFT memory nft = NFT(
                listing.seller,         // seller
                listing.nftContract,    // nftContract
                listing.tokenId,        // tokenId
                listing.price,          // price
                listing.listed,         // listed 
                listing.listingId       // listingId
            );
            nfts[nftsIndex] = nft;
            nftsIndex++;
        }
    }

    return nfts;
}


function getHash(address _signer, address _nftContract, uint256 _tokenId) public view returns (bytes32) { 
    return keccak256(abi.encodePacked(
        "\x19\x01",
        _DOMAIN_SEPARATOR,
        keccak256(abi.encode(
            keccak256("NFTApproval(address signer,address nftContract,uint256 tokenId)"),
            _signer,
            _nftContract,
            _tokenId
        ))
    ));
}

function isSignatureValid(address _signer, bytes32 _hash, bytes memory _signature) private view returns (bool) {
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR, _hash));
    address recoveredSigner = ECDSA.recover(digest, _signature); // Ensure ECDSA.recover usage is correct
    return recoveredSigner == _signer;
}


function requestSignature(address _signer, address _nftContract, uint256 _tokenId) private {
    // 2. Emit an event for your front-end to capture
    emit SignatureRequested(_signer, _nftContract, _tokenId); 
}


function findListingIdByTokenId(uint256 _tokenId) private view returns (uint256, bool) {
    for (uint256 i = 0; i < _listingIdCounter; i++) {
        if (listings[i].tokenId == _tokenId && listings[i].listed) {
            return (i, true); 
        }
    }
    return (0, false); // Return default listingId '0' and 'false' if not found
}

// Temporary helper for debugging in Remix
function getListedTokenIds() public view returns (uint256[] memory) {
    uint256 listedCount = 0;
    for (uint256 i = 0; i < _listingIdCounter; i++) {
        if (listings[i].listed) { 
            listedCount++;
        } 
    }

    uint256[] memory tokenIds = new uint256[](listedCount);
    uint256 index = 0;

    for (uint256 i = 0; i < _listingIdCounter; i++) {
        if (listings[i].listed) { 
            tokenIds[index++] = listings[i].tokenId; 
        } 
    }

    return tokenIds;
}

function withdrawBNB(address payable recipient, uint256 amount) public onlyOwner {
    require(amount > 0, "Withdrawal amount must be greater than 0");
    require(address(this).balance >= amount, "Insufficient BNB balance in the contract");

    recipient.transfer(amount);
}


}
