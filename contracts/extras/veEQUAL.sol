pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract veEQUAL is ReentrancyGuard {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    function create_lock(uint256 _value, uint256 _lock_duration) external nonReentrant returns (uint256) {
        "";
    }

    function createLock(uint256 _value, uint256 _lock_duration) external nonReentrant returns (uint256) {
        "";
    }

    function increase_amount() public {
        "";
    }

    

    function balanceOfNFT(uint256 _id) public view returns (uint256) {
        return 0;
    }

  function split(uint256 _from, uint256 _amount) external returns (uint256 _tokenId1, uint256 _tokenId2) {
    _tokenId1 = 0;
    _tokenId2 = 0;

  }


    function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256[] memory _tokens = new uint256[](1);
        _tokens[0] = 0;
        return _tokens;
    }

    function approve(address _approved, uint256 _tokenId) public {
        "";
    }

    function locked(uint256 id) public view returns (LockedBalance memory) {
        return LockedBalance(0, 0);
    }

    function locked__end(uint256 id) public view returns (uint256) {
        return 0;
    }
}
