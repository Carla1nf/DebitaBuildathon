pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Base64.sol";



// File contracts/NFT.sol

interface IDEBITA {
    function isSenderALoan(address sender) external returns (bool);
}


contract Ownerships is ERC721Enumerable {

    uint id = 0;
    address admin;
    address DebitaContract;
    bool private initialized;



    constructor()  ERC721("Debita Ownerships", "")  {
        admin = msg.sender;

    }

    modifier onlyContract() {
        require(msg.sender == DebitaContract);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == admin && !initialized);
        _;
    }
   
 
    function mint(address to) public  onlyContract() returns(uint256) {
        id++;
        _mint(to, id);
        return id;
    }

    function setDebitaContract(address newContract) public onlyOwner {
      DebitaContract = newContract;
    }

    function burn(uint256 tokenId) public virtual   {
      require(IDEBITA(DebitaContract).isSenderALoan(msg.sender), "Only loans can call this function.");
     _burn(tokenId);
    }
}
