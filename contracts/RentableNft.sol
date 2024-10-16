// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ERC4907.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RentableNft is ERC4907 {
  using Counters for Counters.Counter;
  address private _marketplaceContract;
  Counters.Counter private _tokenIds;

  constructor(address marketplaceContract) ERC4907("RentableNft", "RNFT") {
    _marketplaceContract = marketplaceContract;
  }

  function safeMint(address to, string memory _tokenURI, uint256 tokenId) public {
    // _tokenIds.increment();
    // uint256 newTokenId = _tokenIds.current();
    // _safeMint(to, newTokenId);
    // setApprovalForAll(_marketplaceContract, true);
    // _setTokenURI(newTokenId, _tokenURI);

    _tokenIds.increment();
    _safeMint(to, tokenId);
    setApprovalForAll(_marketplaceContract, true);
    _setTokenURI(tokenId, _tokenURI);
  }

  function burn(uint256 tokenId) public {
    _burn(tokenId);
  }
}
