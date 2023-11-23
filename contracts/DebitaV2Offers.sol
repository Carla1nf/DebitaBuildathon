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
        bool isLendingNFT,
        bool isCollateralNFT,
        uint16 _interestRate,
        uint8 _paymentCount,
        uint32 _timelap,
        uint256 _interestAmount
    ) external returns (address);
}

contract DebitaV2Offers is ReentrancyGuard {
    event LoanCreated(
        address indexed lendingAddress,
        address indexed loanAddress,
        uint lenderId,
        uint borrowerId
    );

    address immutable owner;
    bool immutable isLendingNFT; // If the lender is an NFT
    bool immutable isCollateralNFT; // If the collateral is an NFT
    address immutable lendingAddress; // Address of the lent asset
    address immutable collateralAddress; // Address of the collateral asset
    uint256 immutable lendingAmount_TOTAL;
    uint256 lendingAmount_AVAILABLE;
    uint256 immutable collateralAmount_TOTAL;
    uint256 collateralAmount_AVAILABLE;
    uint16 immutable interest;
    uint immutable interestAmount; // 0 if lending is an ERC-20
    uint8 immutable paymentCount;
    uint32 immutable timelap;
    bool immutable ownerIsLender;
    bool public isActive;
    address immutable debitaFactoryV2;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyActive() {
        require(isActive, "Offer is not active.");
        _;
    }

    constructor(
        address _lendingAddress,
        address _collateralAddress,
        uint256 _lendingAmount,
        uint256 _collateralAmount,
        bool _isLendingNFT,
        bool _isCollateralNFT,
        uint16 _interest,
        uint _interestAmount,
        uint8 _paymentCount,
        uint32 _timelap,
        bool _senderIsLender,
        address _owner
    ) {
        lendingAddress = _lendingAddress;
        collateralAddress = _collateralAddress;
        lendingAmount_TOTAL = _lendingAmount;
        collateralAmount_TOTAL = _collateralAmount;
        interest = _interest;
        interestAmount = _interestAmount;
        paymentCount = _paymentCount;
        timelap = _timelap;
        ownerIsLender = _senderIsLender;
        isCollateralNFT = _isCollateralNFT;
        owner = _owner;
        isLendingNFT = _isLendingNFT;
        isActive = true;
        lendingAmount_AVAILABLE = _lendingAmount;
        collateralAmount_AVAILABLE = _collateralAmount;
        debitaFactoryV2 = msg.sender;
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
            ERC20(assetAddress).transfer(to, assetAmount);
        }
    }

    function cancelOffer() external onlyOwner onlyActive nonReentrant {
        isActive = false;
        if (ownerIsLender) {
            transferAssets(
                address(this),
                owner,
                lendingAddress,
                lendingAmount_AVAILABLE,
                isLendingNFT
            );
        } else {
            transferAssets(
                address(this),
                owner,
                collateralAddress,
                collateralAmount_AVAILABLE,
                isCollateralNFT
            );
        }
    }

    // 10 = 1% from the totalAmount
    function acceptOfferAsBorrower(
        uint porcentage
    ) public nonReentrant onlyActive {
        require(ownerIsLender, "Owner is not lender");
        require(porcentage <= 1000, "Porcentage must be less than 100%");
        require(porcentage >= 10, "Porcentage must be greater than 1%");

        uint256 lendingAmount = (lendingAmount_AVAILABLE * porcentage) / 1000;
        uint256 collateralAmount = (collateralAmount_AVAILABLE * porcentage) /
            1000;

        lendingAmount_AVAILABLE -= lendingAmount;
        collateralAmount_AVAILABLE -= collateralAmount;

        if (lendingAmount_AVAILABLE == 0) {
            isActive = false;
        }

        transferAssets(
            msg.sender,
            address(this),
            collateralAddress,
            collateralAmount,
            isCollateralNFT
        );
        uint[2] memory ids = IDebitaFactoryV2(debitaFactoryV2).mintOwnerships(
            [owner, msg.sender]
        );

        address loanAddress = IDebitaFactoryV2(debitaFactoryV2).createLoanV2(
            ids,
            [lendingAddress, collateralAddress],
            [lendingAmount, collateralAmount],
            isLendingNFT,
            isCollateralNFT,
            interest,
            paymentCount,
            timelap,
            interestAmount
        );
        // Send collateral to loanAddress
        transferAssets(
            address(this),
            address(loanAddress),
            collateralAddress,
            collateralAmount,
            isCollateralNFT
        );

        // Transfer tokens to the borrower
        transferAssets(
            address(this),
            msg.sender,
            lendingAddress,
            lendingAmount,
            isLendingNFT
        );
    }
}
