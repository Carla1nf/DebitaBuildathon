pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ABIERC721 is ERC721 {
    uint256 id;

    constructor() ERC721("ABIERC721", "ABIERC721") {}

    function mint() public {
        id++;
        _mint(msg.sender, id);
    }
}
