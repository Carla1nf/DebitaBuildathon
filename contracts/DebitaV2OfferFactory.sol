pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DebitaV2Offers.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DebitaV2OfferFactory is ReentrancyGuard {
    event CreateOffer(
        address indexed owner,
        address indexed _add,
        bool indexed senderIsLender
    );

       event DeleteOffer(
        address indexed _add,
        bool indexed senderIsLender
    );

    event AcceptOffer(
        address indexed lendingAddress,
        uint indexed lendingAmount
    );

    address owner;
    address public debitaLoanFactoryV2;
    mapping(address => bool) public isSenderAnOffer;
    mapping(address => bool) public isContractVeNFT;

    modifier onlyOwner() {
        require(owner == msg.sender, "Only offers can call this function.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

     /**
     * @dev create Offer
     * @param assetAddresses [0] = Lending, [1] = Collateral
     * @param assetAmounts [0] = Lending, [1] = Collateral
     * @param isAssetNFT [0] = Lending, [1] = Collateral
     * @param _interestRate (1 ==> 0.01%, 1000 ==> 10%, 10000 ==> 100%)
     * @param nftData [0] = NFT ID Lender, [1] NFT ID Collateral, [2] Total amount of interest (If lending is NFT) ---  0 on each if not NFT
     * @param veValue value of wanted locked veNFT (for borrower or lender) (0 if not veNFT)
     * @param _paymentCount Number of payments
     * @param _timelap timelap on each payment
     * @param loanBooleans [0] = isLending (true --> msg.sender is Lender), [1] = isPerpetual
     * @param interest_address address of the erc-20 for interest payments, 0x0 if lending is not NFT
     **/
        
    function createOfferV2(
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory isAssetNFT,
        uint16 _interestRate,
        uint[2] calldata nftData, // In case of NFT, nftData[0] = nftID, nfData[1] = interest Amount
        int128 veValue,
        uint8 _paymentCount,
        uint32 _timelap,
        bool[2] memory loanBooleans,  // isLending, isPerpetual
        address interest_address
    ) external nonReentrant returns (address) {
        if (
            _timelap < 1 days ||
            _timelap > 365 days ||
            assetAmounts[0] == 0 ||
            assetAmounts[1] == 0 ||
            _paymentCount > 10 ||
            _paymentCount == 0 ||
            _paymentCount > assetAmounts[0] ||
            _interestRate > 10000 ||
            (isAssetNFT[0] && _paymentCount > 1) ||
            (isAssetNFT[0] && assetAmounts[0] > 1) ||
            (isAssetNFT[1] && assetAmounts[1] > 1) 
        ) {
            revert();
        }

        DebitaV2Offers newOfferContract = new DebitaV2Offers(
            assetAddresses,
            assetAmounts,
            isAssetNFT,
            _interestRate,
            nftData,
            veValue,
            _paymentCount,
            _timelap,
            loanBooleans,
            [msg.sender, interest_address]
        );
        uint index = loanBooleans[0] ? 0 : 1;
        
        transferAssets(
            msg.sender,
            address(newOfferContract),
            assetAddresses[index],
            assetAmounts[index],
            isAssetNFT[index],
            nftData[0]
        );
        require(IERC20(assetAddresses[index]).balanceOf( address(newOfferContract)) == assetAmounts[index], "Not taxable tokens");
        isSenderAnOffer[address(newOfferContract)] = true;
        emit CreateOffer(msg.sender, address(newOfferContract), loanBooleans[0]);
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
           require(IERC20(assetAddress).transferFrom(from, to, assetAmount), "Amount not sent");
        }
    }

    function setLoanFactoryV2(address _loanFactory) external onlyOwner {
        debitaLoanFactoryV2 = _loanFactory;
    }

    function emitOfferCanceled(bool isOwnerLender) external  {
       require(isSenderAnOffer[msg.sender], "Not an offer");
       emit DeleteOffer(msg.sender, isOwnerLender);

    }

    function emitOfferNoFunds(bool isOwnerLender) external {
       require(isSenderAnOffer[msg.sender], "Not an offer");
       emit DeleteOffer(msg.sender, isOwnerLender);
    }

    function emitOfferFundsAgain(address _owner, bool isOwnerLender) external {
       require(isSenderAnOffer[msg.sender], "Not an offer");
       emit CreateOffer(_owner, msg.sender, isOwnerLender);
    }

    function emitAcceptedOffer(address lendingAddress, uint lendingAmount) external {
       require(isSenderAnOffer[msg.sender], "Not an offer");
       emit AcceptOffer(lendingAddress, lendingAmount);
    }


    function setVeNFT(address _veNFT) external onlyOwner {
        isContractVeNFT[_veNFT] = true;
    }
}
