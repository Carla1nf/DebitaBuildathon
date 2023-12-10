pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract veEQUAL is ReentrancyGuard  {


 struct LockedBalance {
        int128 amount;
        uint end;
    }

    function create_lock(uint _value, uint _lock_duration) external nonReentrant() returns (uint) {
       "";
    }

    function increase_amount() public {
       "";
    }

    function balanceOfNFT(uint _id) public view returns (uint256) {
        return 0;
    }

    function tokensOfOwner(address _owner) public view returns (uint256[] memory)  {
        uint256[] memory _tokens = new uint256[](1);
        _tokens[0] = 0;
        return _tokens;
    }

function approve(address _approved, uint256 _tokenId ) public {
    "";
}


function locked(uint id) public view returns(LockedBalance memory) {
    return LockedBalance(0,0);
}

function locked__end(uint id) public view returns(uint) {
    return 0;
}
    
}