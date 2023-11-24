pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IDebitaFactoryV2 {
    function mintOwnerships(
        address[2] calldata owners
    ) external returns (uint[2] memory);

    function createLoanV2(
        uint[2] calldata nftIDS,
        address[2] calldata assetAddresses,
        uint256[2] calldata assetAmounts,
        bool[2] calldata isAssetNFT,
        uint16 _interestRate,
        uint8 _paymentCount,
        uint32 _timelap,
        uint256 _interestAmount,
        address interest_address
    ) external returns (address);
}

contract DebitaV2Offers is ReentrancyGuard {

    event LoanCreated(
        address indexed lendingAddress,
        address indexed loanAddress,
        uint lenderId,
        uint borrowerId
    );

    struct OfferInfo {
        address[2] assetAddresses;
        uint256[2] assetAmounts;
        bool[2] isAssetNFT;
        uint16 interestRate;
        uint256 _interestAmount; // in case lending is NFT else 0
        uint8 paymentCount;
        uint32 _timelap;
        bool isLending;
        bool isActive;
        address interest_address; // in case lending is NFT else 0
    }

    OfferInfo storage_OfferInfo;

    address immutable owner;
    address immutable debitaFactoryV2;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyActive() {
        require(storage_OfferInfo.isActive, "Offer is not active.");
        _;
    }

    constructor(
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory isAssetNFT,
        uint8 _interestRate,
        uint _interestAmount,
        uint8 _paymentCount,
        uint32 _timelap,
        bool isLending,
        address _owner,
        address interest_address
    ) {
        storage_OfferInfo = OfferInfo({
            assetAddresses: assetAddresses,
            assetAmounts: assetAmounts,
            isAssetNFT: isAssetNFT,
            interestRate: _interestRate,
            _interestAmount: _interestAmount,
            paymentCount: _paymentCount,
            _timelap: _timelap,
            isLending: isLending,
            isActive: true,
            interest_address: interest_address
        });
        owner = _owner;
        debitaFactoryV2 = msg.sender;
    }

    function cancelOffer() external onlyOwner onlyActive nonReentrant {
        OfferInfo memory m_offer = storage_OfferInfo;
        storage_OfferInfo.isActive = false;
        uint index = m_offer.isLending ? 0 : 1;
        transferAssets(
            address(this),
            owner,
            m_offer.assetAddresses[index],
            m_offer.assetAmounts[index],
            m_offer.isAssetNFT[index]
        );
    }

    // 10 = 1% from the totalAmount
    function acceptOfferAsBorrower(
        uint porcentage
    ) public nonReentrant onlyActive {
        OfferInfo memory m_offer = storage_OfferInfo;
        require(m_offer.isLending, "Owner is not lender");
        require(porcentage <= 1000, "Porcentage must be less than 100%");
        require(porcentage >= 10, "Porcentage must be greater than 1%");

        // [0]: Lending  [1]: Collateral
        uint256 lendingAmount = (m_offer.assetAmounts[0] * porcentage) / 1000;
        uint256 collateralAmount = (m_offer.assetAmounts[1] * porcentage) /
            1000;

        m_offer.assetAmounts[0] -= lendingAmount;
        m_offer.assetAmounts[1] -= collateralAmount;

        if (m_offer.assetAmounts[0] == 0) {
            storage_OfferInfo.isActive = false;
        }

        transferAssets(
            msg.sender,
            address(this),
            m_offer.assetAddresses[1],
            collateralAmount,
            m_offer.isAssetNFT[1]
        );
        storage_OfferInfo = m_offer;
        
        uint[2] memory ids = IDebitaFactoryV2(debitaFactoryV2).mintOwnerships(
            [owner, msg.sender]
        );
        address loanAddress = IDebitaFactoryV2(debitaFactoryV2).createLoanV2(
            ids,
            m_offer.assetAddresses,
            [lendingAmount, collateralAmount],
            m_offer.isAssetNFT,
            m_offer.interestRate,
            m_offer.paymentCount,
            m_offer._timelap,
            m_offer._interestAmount,
            m_offer.interest_address
        );

        // Send collateral to loanAddress
        transferAssets(
            address(this),
            address(loanAddress),
            m_offer.assetAddresses[1],
            collateralAmount,
            m_offer.isAssetNFT[1]
        );

        // Transfer tokens to the borrower
        transferAssets(
            address(this),
            msg.sender,
             m_offer.assetAddresses[0],
            lendingAmount,
            m_offer.isAssetNFT[0]
        );
       
    }


function acceptOfferAsLender(
        uint porcentage
    ) public nonReentrant onlyActive {
        OfferInfo memory m_offer = storage_OfferInfo;
        require(!m_offer.isLending, "Owner is not borrower");
        require(porcentage <= 1000, "Porcentage must be less than 100%");
        require(porcentage >= 10, "Porcentage must be greater than 1%");

        // [0]: Lending  [1]: Collateral
        uint256 lendingAmount = (m_offer.assetAmounts[0] * porcentage) / 1000;
        uint256 collateralAmount = (m_offer.assetAmounts[1] * porcentage) /
            1000;

        m_offer.assetAmounts[0] -= lendingAmount;
        m_offer.assetAmounts[1] -= collateralAmount;

        if (m_offer.assetAmounts[0] == 0) {
            storage_OfferInfo.isActive = false;
        }
        
        // Sending Lending Assets to contract
        transferAssets(
            msg.sender,
            address(this),
            m_offer.assetAddresses[0],
            lendingAmount,
            m_offer.isAssetNFT[0]
        );
        storage_OfferInfo = m_offer;
        
        uint[2] memory ids = IDebitaFactoryV2(debitaFactoryV2).mintOwnerships(
            [ msg.sender, owner]
        );
        address loanAddress = IDebitaFactoryV2(debitaFactoryV2).createLoanV2(
            ids,
            m_offer.assetAddresses,
            [lendingAmount, collateralAmount],
            m_offer.isAssetNFT,
            m_offer.interestRate,
            m_offer.paymentCount,
            m_offer._timelap,
            m_offer._interestAmount,
            m_offer.interest_address
        );

        // Send collateral to loanAddress
        transferAssets(
            address(this),
            address(loanAddress),
            m_offer.assetAddresses[1],
            collateralAmount,
            m_offer.isAssetNFT[1]
        );

        // Transfer tokens to the borrower
        transferAssets(
            address(this),
            msg.sender,
             m_offer.assetAddresses[0],
            lendingAmount,
            m_offer.isAssetNFT[0]
        );
       
    }


     function getOffersData() public view returns (OfferInfo memory) {
        return storage_OfferInfo;
    }

    function transferAssets(
        address from,
        address to,
        address assetAddress,
        uint256 assetAmount,
        bool isNFT
    ) internal {
        if (isNFT) {
            ERC721(assetAddress).transferFrom(from, to, assetAmount);
        } else {
            if(from == address(this)) {
                ERC20(assetAddress).transfer(to, assetAmount);
            } else {
                ERC20(assetAddress).transferFrom(from, to, assetAmount);
            }
        }
    }

   
}
