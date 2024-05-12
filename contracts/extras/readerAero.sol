pragma solidity ^0.8.0;

interface veAero {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }
    
    function balanceOf(address _owner) external view returns (uint256);
    function tokensOfOwner(address _owner) external view returns (uint256[] memory);
    function locked(uint256 id) external view returns (LockedBalance memory);
    function voted(uint256 id) external view returns (bool);
    function ownerToNFTokenIdList(address _owner, uint index) external view returns (uint256);
}


contract ReaderVeAero {



struct InfoveNFT {
    uint id;
    int128 amount;
    bool voted;
}

address constant veAeroAddress = 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4;

function getDataFrom(address _add) public view returns(InfoveNFT[] memory) {
 
      uint256 balanceLength = veAero(veAeroAddress).balanceOf(_add);
      InfoveNFT[] memory _allinfos = new InfoveNFT[](balanceLength);

       for(uint i; i < balanceLength; i++) {
       uint _id = veAero(veAeroAddress).ownerToNFTokenIdList(_add, i);
       int128 _amount = veAero(veAeroAddress).locked(_id).amount;
       bool _voted = veAero(veAeroAddress).voted(_id);
       InfoveNFT memory _thisInfo = InfoveNFT({
        id: _id,
        amount: _amount,
        voted: _voted
       });
       _allinfos[i] = (_thisInfo);
      }

      return _allinfos;

 
}

}