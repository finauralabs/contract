// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./IERC4907.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace is ReentrancyGuard, EIP712, Ownable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    Counters.Counter private _nftsListed;
    address private _marketOwner;
    uint256 private _listingFee = .001 ether;
    // maps contract address to token id to properties of the rental listing
    mapping(address => mapping(uint256 => Listing)) private _listingMap;
    // maps nft contracts to set of the tokens that are listed
    mapping(address => EnumerableSet.UintSet) private _nftContractTokensMap;
    // tracks the nft contracts that have been listed
    EnumerableSet.AddressSet private _nftContracts;

    mapping(address => mapping(uint256 => bool)) private _usedNonces;

    mapping(address => mapping(uint256 => mapping(address => Bid))) private _bids;
    mapping(address => mapping(uint256 => address[])) private _bidders;

    // bytes32 private constant LAZY_LISTING_TYPEHASH = 0x495b21dd00b5941776b0e88a416f82d1f7d45858e83b54d147c314a79140ee03;
    // keccak256(
    //     "LazyListing(address owner,address nftContract,uint256 tokenId,uint256 pricePerDay,uint256 price,uint256 startDateUNIX,uint256 endDateUNIX,uint256 nonce)"
    // );

    struct Listing {
        address owner;
        address user;
        address nftContract;
        uint256 tokenId;
        uint256 pricePerDay;
        uint256 price;
        uint256 startDateUNIX; // when the nft can start being rented
        uint256 endDateUNIX; // when the nft can no longer be rented
        uint256 expires; // when the user can no longer rent it
    }

    struct Bid {
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address bidder;
    }

    // struct LazyListingVoucher {
    //     address owner;
    //     address nftContract;
    //     uint256 tokenId;
    //     uint256 pricePerDay;
    //     uint256 price;
    //     uint256 startDateUNIX;
    //     uint256 endDateUNIX;
    //     uint256 nonce;
    // }

    event NFTListed(
        address owner,
        address user,
        address nftContract,
        uint256 tokenId,
        uint256 pricePerDay,
        uint256 price,
        uint256 startDateUNIX,
        uint256 endDateUNIX,
        uint256 expires
    );

    event NFTRented(
        address owner,
        address user,
        address nftContract,
        uint256 tokenId,
        uint256 startDateUNIX,
        uint256 endDateUNIX,
        uint64 expires,
        uint256 rentalFee
    );

    event NFTUnlisted(address unlistSender, address nftContract, uint256 tokenId, uint256 refund);

    event NFTSold(address seller, address buyer, address nftContract, uint256 tokenId, uint256 price);

    event NFTBid(address indexed bidder, address indexed nftContract, uint256 tokenId, uint256 price);

    constructor() EIP712("NFT Marketplace", "1") {
        _marketOwner = msg.sender;
    }

    // function to list NFT for rental
    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 pricePerDay,
        uint256 price,
        uint256 startDateUNIX,
        uint256 endDateUNIX
    ) public payable nonReentrant {
        require(isRentableNFT(nftContract), "Contract is not an ERC4907");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner of nft");
        // require(msg.value == _listingFee, "Not enough ether for listing fee");
        require(pricePerDay > 0, "Rental price should be greater than 0");
        require(price > 0, "Buyout price should be greater than 0");
        require(startDateUNIX >= block.timestamp, "Start date cannot be in the past");
        require(endDateUNIX >= startDateUNIX, "End date cannot be before the start date");
        require(_listingMap[nftContract][tokenId].nftContract == address(0), "This NFT has already been listed");

        // payable(_marketOwner).transfer(_listingFee);
        _listingMap[nftContract][tokenId] = Listing(
            msg.sender,
            address(0),
            nftContract,
            tokenId,
            pricePerDay,
            price,
            startDateUNIX,
            endDateUNIX,
            0
        );
        _nftsListed.increment();
        EnumerableSet.add(_nftContractTokensMap[nftContract], tokenId);
        EnumerableSet.add(_nftContracts, nftContract);
        emit NFTListed(
            IERC721(nftContract).ownerOf(tokenId),
            address(0),
            nftContract,
            tokenId,
            pricePerDay,
            price,
            startDateUNIX,
            endDateUNIX,
            0
        );
    }

    function isRentableNFT(address nftContract) public view returns (bool) {
        bool _isRentable = false;
        bool _isNFT = false;
        try IERC165(nftContract).supportsInterface(type(IERC4907).interfaceId) returns (bool rentable) {
            _isRentable = rentable;
        } catch {
            return false;
        }
        try IERC165(nftContract).supportsInterface(type(IERC721).interfaceId) returns (bool nft) {
            _isNFT = nft;
        } catch {
            return false;
        }
        return _isRentable && _isNFT;
    }

    // function to rent an NFT
    function rentNFT(address nftContract, uint256 tokenId, uint64 expires) public payable nonReentrant {
        Listing storage listing = _listingMap[nftContract][tokenId];
        require(listing.user == address(0) || block.timestamp > listing.expires, "NFT already rented");
        require(expires <= listing.endDateUNIX, "Rental period exceeds max date rentable");
        // Transfer rental fee
        uint256 numDays = (expires - block.timestamp) / 60 / 60 / 24 + 1;
        uint256 rentalFee = listing.pricePerDay * numDays;
        require(msg.value >= rentalFee, "Not enough ether to cover rental period");
        payable(listing.owner).transfer(rentalFee);
        // Update listing
        IERC4907(nftContract).setUser(tokenId, msg.sender, expires);
        listing.user = msg.sender;
        listing.expires = expires;

        emit NFTRented(
            IERC721(nftContract).ownerOf(tokenId),
            msg.sender,
            nftContract,
            tokenId,
            listing.startDateUNIX,
            listing.endDateUNIX,
            expires,
            rentalFee
        );
    }

    function buyNFT(address nftContract, uint256 tokenId) public payable nonReentrant {
        Listing storage listing = _listingMap[nftContract][tokenId];
        require(listing.owner != address(0), "This NFT is not listed");
        require(msg.value >= listing.price, "Not enough ether to buy NFT");

        IERC721(nftContract).safeTransferFrom(listing.owner, msg.sender, tokenId);
        payable(listing.owner).transfer(listing.price);

        EnumerableSet.remove(_nftContractTokensMap[nftContract], tokenId);
        delete _listingMap[nftContract][tokenId];
        if (EnumerableSet.length(_nftContractTokensMap[nftContract]) == 0) {
            EnumerableSet.remove(_nftContracts, nftContract);
        }
        _nftsListed.decrement();

        emit NFTSold(listing.owner, msg.sender, nftContract, tokenId, listing.price);
    }

    // function to unlist your rental, refunding the user for any lost time
    function unlistNFT(address nftContract, uint256 tokenId) public payable nonReentrant {
        Listing storage listing = _listingMap[nftContract][tokenId];
        require(listing.owner != address(0), "This NFT is not listed");
        require(listing.owner == msg.sender || _marketOwner == msg.sender, "Not approved to unlist NFT");
        // fee to be returned to user if unlisted before rental period is up
        // nothing to refund if no renter
        uint256 refund = 0;
        if (listing.user != address(0)) {
            refund = ((listing.expires - block.timestamp) / 60 / 60 / 24 + 1) * listing.pricePerDay;
            require(msg.value >= refund, "Not enough ether to cover refund");
            payable(listing.user).transfer(refund);
        }
        // clean up data
        IERC4907(nftContract).setUser(tokenId, address(0), 0);
        EnumerableSet.remove(_nftContractTokensMap[nftContract], tokenId);
        delete _listingMap[nftContract][tokenId];
        if (EnumerableSet.length(_nftContractTokensMap[nftContract]) == 0) {
            EnumerableSet.remove(_nftContracts, nftContract);
        }
        _nftsListed.decrement();

        emit NFTUnlisted(msg.sender, nftContract, tokenId, refund);
    }

    function offerBid(address nftContract, uint256 tokenId) public payable nonReentrant {
        require(nftContract != address(0), "Invalid NFT contract address");
        require(tokenId != 0, "Invalid token ID");
        require(msg.value > 0, "Not enough ether for bid");

        require(_bids[nftContract][tokenId][msg.sender].bidder == address(0), "Bid already exists");

        payable(_marketOwner).transfer(msg.value);
        _bids[nftContract][tokenId][msg.sender] = Bid(
            nftContract,
            tokenId,
            msg.value,
            msg.sender
        );
        _bidders[nftContract][tokenId].push(msg.sender);

        emit NFTBid(msg.sender, nftContract, tokenId, msg.value);
    }

    function makeDeal(address nftContract, uint256 tokenId, address buyer) public payable {
        require(nftContract != address(0), "Invalid NFT contract address");
        require(tokenId != 0, "Invalid token ID");

        Listing storage listing = _listingMap[nftContract][tokenId];
        require(listing.user != address(0), "This NFT is not listed");
        require(listing.owner == msg.sender || _marketOwner == msg.sender, "Not approved to make deal for NFT");

        mapping(address => Bid) storage bids = _bids[nftContract][tokenId];
        require(bids[buyer].bidder != address(0), "No bids found for this NFT");

        address[] memory bidders = _bidders[nftContract][tokenId];
        uint256 offerPrice = 0;

        for (uint256 i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            uint256 price = bids[bidder].price;
            if (bidder == buyer) {
                offerPrice = price;
                payable(listing.owner).transfer(offerPrice);
            } else {
                payable(bidder).transfer(price);
            }
            delete bids[bidder];
        }

        delete _bidders[nftContract][tokenId];

        emit NFTSold(listing.owner, buyer, nftContract, tokenId, offerPrice);
    }

    /*
     * function to get all listings
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function getAllListings() public view returns (Listing[] memory) {
        Listing[] memory listings = new Listing[](_nftsListed.current());
        uint256 listingsIndex = 0;
        address[] memory nftContracts = EnumerableSet.values(_nftContracts);
        for (uint i = 0; i < nftContracts.length; i++) {
            address nftAddress = nftContracts[i];
            uint256[] memory tokens = EnumerableSet.values(_nftContractTokensMap[nftAddress]);
            for (uint j = 0; j < tokens.length; j++) {
                listings[listingsIndex] = _listingMap[nftAddress][tokens[j]];
                listingsIndex++;
            }
        }
        return listings;
    }

    function getListingFee() public view returns (uint256) {
        return _listingFee;
    }

    // function rentLazyListedNFT(
    //     LazyListingVoucher calldata voucher,
    //     uint64 expires,
    //     bytes calldata signature
    // ) external payable nonReentrant {
    //     require(isRentableNFT(voucher.nftContract), "Contract is not an ERC4907");
    //     require(IERC721(voucher.nftContract).ownerOf(voucher.tokenId) == voucher.owner, "Not owner of nft");
    //     require(expires <= voucher.endDateUNIX, "Rental period exceeds max date rentable");
    //     require(!_usedNonces[voucher.owner][voucher.nonce], "Nonce already used");
    //
    //     bytes32 structHash = keccak256(
    //         abi.encode(
    //             LAZY_LISTING_TYPEHASH,
    //             voucher.owner,
    //             voucher.nftContract,
    //             voucher.tokenId,
    //             voucher.pricePerDay,
    //             voucher.startDateUNIX,
    //             voucher.endDateUNIX,
    //             voucher.nonce
    //         )
    //     );
    //     bytes32 hash = _hashTypedDataV4(structHash);
    //     address signer = ECDSA.recover(hash, signature);
    //     require(signer == voucher.owner, "Invalid signature");
    //
    //     uint256 numDays = (expires - block.timestamp) / 60 / 60 / 24 + 1;
    //     uint256 rentalFee = voucher.pricePerDay * numDays;
    //     require(msg.value >= rentalFee, "Not enough ether to cover rental period");
    //
    //     payable(voucher.owner).transfer(rentalFee);
    //     IERC4907(voucher.nftContract).setUser(voucher.tokenId, msg.sender, expires);
    //     _usedNonces[voucher.owner][voucher.nonce] = true;
    //
    //     emit NFTRented(
    //         voucher.owner,
    //         msg.sender,
    //         voucher.nftContract,
    //         voucher.tokenId,
    //         voucher.startDateUNIX,
    //         voucher.endDateUNIX,
    //         expires,
    //         rentalFee
    //     );
    // }
    //
    // function buyLazyListedNFT(
    //     LazyListingVoucher calldata voucher,
    //     bytes calldata signature
    // ) external payable nonReentrant {
    //     require(isRentableNFT(voucher.nftContract), "Contract is not an ERC4907");
    //     require(IERC721(voucher.nftContract).ownerOf(voucher.tokenId) == voucher.owner, "Not owner of nft");
    //     require(!_usedNonces[voucher.owner][voucher.nonce], "Nonce already used");
    //     require(msg.value >= voucher.price, "Not enough ether to buy NFT");
    //
    //     bytes32 structHash = keccak256(
    //         abi.encode(
    //             LAZY_LISTING_TYPEHASH,
    //             voucher.owner,
    //             voucher.nftContract,
    //             voucher.tokenId,
    //             voucher.pricePerDay,
    //             voucher.price,
    //             voucher.startDateUNIX,
    //             voucher.endDateUNIX,
    //             voucher.nonce
    //         )
    //     );
    //     bytes32 hash = _hashTypedDataV4(structHash);
    //     address signer = ECDSA.recover(hash, signature);
    //     require(signer == voucher.owner, "Invalid signature");
    //
    //     require(
    //         IERC721(voucher.nftContract).getApproved(voucher.tokenId) == address(this) ||
    //             IERC721(voucher.nftContract).isApprovedForAll(voucher.owner, address(this)),
    //         "Marketplace not approved to transfer NFT"
    //     );
    //
    //     IERC721(voucher.nftContract).safeTransferFrom(voucher.owner, msg.sender, voucher.tokenId);
    //     payable(voucher.owner).transfer(voucher.price);
    //     _usedNonces[voucher.owner][voucher.nonce] = true;
    //
    //     emit NFTSold(voucher.owner, msg.sender, voucher.nftContract, voucher.tokenId, voucher.price);
    // }
}
