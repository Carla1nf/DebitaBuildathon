pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface debitaMultiPool {
    function handleDefault(uint amount) external;
}
interface auctionFactory {
    function getLiquidationFloorPrice(
        uint initAmount
    ) external view returns (uint);
    function emitAuctionEdited(address auctionAddress, uint newFloor) external;
    function emitAuctionDeleted(address auctionAddress) external;
}

contract dutchAuction_veNFT is ERC721Holder {
    struct dutchAuction_INFO {
        uint nftCollateralID;
        address sellingToken;
        uint initAmount;
        uint floorAmount;
        uint duration;
        uint endBlock;
        uint tickPerBlock;
        bool isActive;
        uint initialBlock;
        bool isLiquidation;
    }

    dutchAuction_INFO public s_CurrentAuction;
    address public s_veNFTAddress;
    address public s_ownerOfAuction;
    address public factory;

    modifier onlyActiveAuction() {
        require(s_CurrentAuction.isActive, "Auction is not active");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == s_ownerOfAuction, "Only the owner");
        _;
    }

    constructor(
        uint _veNFTID,
        address _veNFTAddress,
        address sellingToken,
        address owner,
        uint _initAmount,
        uint _floorAmount,
        uint _duration,
        bool _isLiquidation
    ) {
        s_CurrentAuction = dutchAuction_INFO({
            nftCollateralID: _veNFTID,
            sellingToken: sellingToken,
            initAmount: _initAmount,
            floorAmount: _floorAmount,
            duration: _duration,
            endBlock: block.timestamp + _duration,
            tickPerBlock: (_initAmount - _floorAmount) / _duration,
            isActive: true,
            initialBlock: block.timestamp,
            isLiquidation: _isLiquidation
        });

        s_ownerOfAuction = owner;
        s_veNFTAddress = _veNFTAddress;
        factory = msg.sender;
    }

    function buyNFT() public onlyActiveAuction {
        dutchAuction_INFO memory m_currentAuction = s_CurrentAuction;
        uint currentPrice = getCurrentPrice();
        s_CurrentAuction.isActive = false;

        // Transfer liquidation token from the buyer to the owner of the auction
        SafeERC20.safeTransferFrom(
            IERC20(m_currentAuction.sellingToken),
            msg.sender,
            s_ownerOfAuction,
            currentPrice
        );

        // If it's a liquidation, handle it properly
        if (m_currentAuction.isLiquidation) {
            debitaMultiPool(s_ownerOfAuction).handleDefault(currentPrice);
        }
        IERC721 Token = IERC721(s_veNFTAddress);
        Token.safeTransferFrom(
            address(this),
            msg.sender,
            s_CurrentAuction.nftCollateralID
        );

        auctionFactory(factory).emitAuctionDeleted(address(this));
        // event offerBought
    }

    function cancelOffer() public onlyActiveAuction onlyOwner {
        s_CurrentAuction.isActive = false;
        // Send NFT back to owner
        IERC721 Token = IERC721(s_veNFTAddress);
        Token.safeTransferFrom(
            address(this),
            s_ownerOfAuction,
            s_CurrentAuction.nftCollateralID
        );

        auctionFactory(factory).emitAuctionDeleted(address(this));
        // event offerCanceled
    }

    // chequear esto

    // check potencial error con resetear el initial block
    function editFloorPrice(
        uint newFloorAmount
    ) public onlyActiveAuction onlyOwner {
        require(
            s_CurrentAuction.floorAmount > newFloorAmount,
            "New floor lower"
        );

        dutchAuction_INFO memory m_currentAuction = s_CurrentAuction;
        uint activeBlocks = (m_currentAuction.initAmount -
            m_currentAuction.floorAmount) / m_currentAuction.tickPerBlock;

        if ((m_currentAuction.initialBlock + activeBlocks) < block.timestamp) {
            // ticket = tokens por bloque   tokens / tokens por bloque = bloques
            m_currentAuction.initialBlock = block.timestamp - (activeBlocks);
        }

        m_currentAuction.floorAmount = newFloorAmount;
        s_CurrentAuction = m_currentAuction;

        auctionFactory(factory).emitAuctionEdited(
            address(this),
            newFloorAmount
        );
        // emit offer edited
    }

    function getCurrentPrice() public view returns (uint) {
        dutchAuction_INFO memory m_currentAuction = s_CurrentAuction;
        uint floorPrice = m_currentAuction.floorAmount;

        if (m_currentAuction.isLiquidation) {
            // calculate Floor price
            floorPrice = auctionFactory(factory).getLiquidationFloorPrice(
                m_currentAuction.initAmount
            );
        }

        uint timePassed = block.timestamp - m_currentAuction.initialBlock;
        uint decreasedAmount = m_currentAuction.tickPerBlock * timePassed;
        uint currentPrice = (decreasedAmount >
            (m_currentAuction.initAmount - floorPrice))
            ? floorPrice
            : m_currentAuction.initAmount - decreasedAmount;
        // Calculate the current price in case timePassed is false
        // Check if time has passed

        return currentPrice;
    }
}
