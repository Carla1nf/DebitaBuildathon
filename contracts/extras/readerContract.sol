pragma solidity ^0.8.0;

interface IveEQUAL {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }
    
    function tokensOfOwner(address _owner) external view returns (uint256[] memory);
    function locked(uint256 id) external view returns (LockedBalance memory);
    function voted(uint256 id) external view returns (bool);
}


contract ReaderVeNFT {



struct InfoveNFT {
    uint id;
    int128 amount;
    bool voted;
}

address constant veEqualAddress = 0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94;

function getDataFrom(address _add) public view returns(InfoveNFT[] memory) {
 
      uint256[] memory allIDs = IveEQUAL(veEqualAddress).tokensOfOwner(_add);
      InfoveNFT[] memory _allinfos = new InfoveNFT[](allIDs.length);
       for(uint i; i < allIDs.length; i++) {

       int128 _amount = IveEQUAL(veEqualAddress).locked(allIDs[i]).amount;
       bool _voted = IveEQUAL(veEqualAddress).voted(allIDs[i]);
       InfoveNFT memory _thisInfo = InfoveNFT({
        id: allIDs[i],
        amount: _amount,
        voted: _voted
       });
       _allinfos[i] = (_thisInfo);
      }

      return _allinfos;

 
}

}