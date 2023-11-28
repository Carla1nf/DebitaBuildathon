pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DebitaV2Offers.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract DebitaV2OfferFactory is ReentrancyGuard {
    event OfferCreated(
        address indexed owner,
        address indexed _add,
        bool indexed senderIsLender
    );


    address  owner;
    address public debitaLoanFactoryV2;
    mapping(address => bool) public isSenderAnOffer;



    modifier onlyOwner() {
        require(owner == msg.sender, "Only offers can call this function.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // interestRate (1 ==> 0.01%, 1000 ==> 10%, 10000 ==> 100%)
    function createOfferV2(
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory isAssetNFT,
        uint16 _interestRate,
        uint[3] calldata nftData, // In case of NFT, nftData[0] = nftID, nftData[1] = value of veNFT (0 if not veNFT) nfData[2] = interest Amount
        uint8 _paymentCount,
        uint32 _timelap,
        bool isLending,
        address interest_address,
        bool perpetual

    ) external nonReentrant returns (address) {
        if (
            _timelap < 1 days ||
            _timelap > 365 days ||
            assetAmounts[0] == 0 ||
            _paymentCount > 10 ||
            _paymentCount == 0 ||
            _paymentCount > assetAmounts[0] ||
            _interestRate > 10000 ||
            isAssetNFT[0] && _paymentCount > 1 || 
            isAssetNFT[0] && assetAmounts[0] > 1 || 
            isAssetNFT[1] && assetAmounts[1] > 1 
        ) {
            revert();
        }

        DebitaV2Offers newOfferContract = new DebitaV2Offers(
            assetAddresses,
            assetAmounts,
            isAssetNFT,
            _interestRate,
            nftData,
            _paymentCount,
            _timelap,
            isLending,
            perpetual,
            msg.sender,
            interest_address
        );
        uint index = isLending ? 0 : 1;
        transferAssets(
                msg.sender,
                address(newOfferContract),
                assetAddresses[index],
                assetAmounts[index],
                isAssetNFT[index],
                nftData[0]
            );

        isSenderAnOffer[address(newOfferContract)] = true;
        emit OfferCreated(msg.sender, address(newOfferContract), true);
        return address(newOfferContract);
    }

 

    function transferAssets(
        address from,
        address to,
        address assetAddress,
        uint256 assetAmount,
        bool isNFT,
        uint nftID
    ) internal {
        if (isNFT) {
            ERC721(assetAddress).transferFrom(from, to, nftID);
        } else {
            IERC20(assetAddress).transferFrom(from, to, assetAmount);
        }
    }
    
    function setLoanFactoryV2(address _loanFactory) external onlyOwner {
        debitaLoanFactoryV2 = _loanFactory;
    }

   
}
