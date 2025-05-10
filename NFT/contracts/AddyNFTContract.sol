// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Add all the necessary OpenZeppelin imports here
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract AddyNFTContract is ERC721, ERC721URIStorage, Ownable {
    uint256 public constant MINT_PRICE = 1 ether; // 1 MNT
    uint256 private _nextTokenId;
    
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(msg.sender) {}

    function mint(address to, string memory uri) public payable {
        if (_nextTokenId > 0) {
            require(msg.value >= MINT_PRICE, "Insufficient payment");
        }
        
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    // Override required functions
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}