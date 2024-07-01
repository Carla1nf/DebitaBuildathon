pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract dToken is ERC721Enumerable {
    address public poolOwner;
    uint id;

    modifier onlyPool() {
        require(msg.sender == poolOwner, "Only pool");
        _;
    }

    constructor(address _poolOwner) ERC721("dToken", "DT") {
        poolOwner = _poolOwner;
    }

    function mintDToken(address to) public onlyPool returns (uint) {
        id++;
        _mint(to, id);
    }

    function burnDToken(uint tokenId) public onlyPool {
        _burn(tokenId);
    }
}
