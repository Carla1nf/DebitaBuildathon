pragma solidity ^0.8.0;

import "./auction.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface debitaMultiPoolFactory {
    function isSenderAPool(address) external view returns (bool);
}

contract auctionFactoryDebita {
    event createdAuction(
        address indexed auctionAddress,
        address indexed creator
    );
    event auctionEdited(address indexed auctionAddress, uint indexed newFloor);
    event auctionEnded(address indexed auctionAddress);

    mapping(address => bool) public isAuction;
    // 15%
    uint public RATIO_LIQUIDATION = 1500;
    address owner;
    address multiPoolFactory;
    constructor(address _multiPoolFactory) {
        owner = msg.sender;
        multiPoolFactory = _multiPoolFactory;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    modifier onlyAuctions() {
        require(isAuction[msg.sender], "Only auctions");
        _;
    }

    function createAuction(
        uint _veNFTID,
        address _veNFTAddress,
        address liquidationToken,
        uint _initAmount,
        uint _floorAmount,
        uint _duration
    ) public returns (address) {
        dutchAuction_veNFT _createdAuction = new dutchAuction_veNFT(
            _veNFTID,
            _veNFTAddress,
            liquidationToken,
            msg.sender,
            _initAmount,
            _floorAmount,
            _duration,
            debitaMultiPoolFactory(multiPoolFactory).isSenderAPool(msg.sender)
        );

        // Transfer veNFT
        IERC721(_veNFTAddress).safeTransferFrom(
            msg.sender,
            address(_createdAuction),
            _veNFTID,
            ""
        );
        isAuction[address(_createdAuction)] = true;
        emit createdAuction(address(_createdAuction), msg.sender);
        return address(_createdAuction);
    }

    function getLiquidationFloorPrice(
        uint initAmount
    ) public view returns (uint) {
        return (initAmount * RATIO_LIQUIDATION) / 10000;
    }

    function setRatio(uint _ratio) public onlyOwner {
        // Less than 30% and more than 5%
        require(_ratio <= 3000 && _ratio >= 500, "Invalid ratio");
        RATIO_LIQUIDATION = _ratio;
    }

    function emitAuctionDeleted(address _auctionAddress) public onlyAuctions {
        emit auctionEnded(_auctionAddress);
    }

    function emitAuctionEdited(
        address _auctionAddress,
        uint _newFloor
    ) public onlyAuctions {
        emit auctionEdited(_auctionAddress, _newFloor);
    }

    // Events mints
}
