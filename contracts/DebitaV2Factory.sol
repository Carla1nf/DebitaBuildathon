pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./DebitaV2Offers.sol";
import "./DebitaV2Loan.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DebitaV2Factory is ReentrancyGuard {
    event OfferCreated(
        address indexed owner,
        address indexed _add,
        bool indexed senderIsLender
    );

    event LoanCreated(
        uint  lenderId,
        uint  borrowerId,
        address indexed lendingAddress,
        address indexed loanAddress
    );

    mapping(address => address) public voterEachveNft;
    mapping(address => bool) public isSenderAnOffer;

    modifier onlyOffers() {
        require(isSenderAnOffer[msg.sender], "Only offers can call this function.");
        _;
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
            ERC20(assetAddress).transferFrom(from, to, assetAmount);
        }
    }

    function createOfferV2(
        address lendingAddress,
        address collateralAddress,
        uint256 lendingAmount,
        uint256 collateralAmount,
        bool isLendingNFT,
        bool isCollateralNFT,
        uint8 _interestRate,
        uint _interestAmount,
        uint8 _paymentCount,
        uint32 _timelap,
        bool isLending
    ) external nonReentrant returns (address) {
        if (
            _timelap < 1 days ||
            _timelap > 365 days ||
            lendingAmount == 0 ||
            _paymentCount > 10 ||
            _paymentCount == 0 ||
            _paymentCount > lendingAmount ||
            _interestRate > 10000
        ) {
            revert();
        }

        DebitaV2Offers newOfferContract = new DebitaV2Offers(
            lendingAddress,
            collateralAddress,
            lendingAmount,
            collateralAmount,
            isLendingNFT,
            isCollateralNFT,
            _interestRate,
            _interestAmount,
            _paymentCount,
            _timelap,
            true,
            msg.sender
        );

        if (isLending) {
            transferAssets(
                msg.sender,
                address(newOfferContract),
                lendingAddress,
                lendingAmount,
                isLendingNFT
            );
        } else {
            transferAssets(
                msg.sender,
                address(newOfferContract),
                collateralAddress,
                collateralAmount,
                isCollateralNFT
            );
        }

        isSenderAnOffer[address(newOfferContract)] = true;
        emit OfferCreated(msg.sender, address(newOfferContract), true);
        return address(newOfferContract);
    }

    function createLoanV2(
        uint8[2] calldata nftIDS,
        address[2] calldata assetAddresses,
        uint256[2] calldata assetAmounts,
        bool isLendingNFT,
        bool isCollateralNFT,
        uint8 _interestRate,
        uint8 _paymentCount,
        uint32 _timelap,
        uint256 _interestAmount
    ) public onlyOffers() nonReentrant() returns(address) {
        
        DebitaV2Loan newLoan = new DebitaV2Loan(
            nftIDS[0],
            nftIDS[1],
            assetAddresses[0],
            assetAddresses[1],
            assetAmounts[0],
            assetAmounts[1],
            isLendingNFT,
            isCollateralNFT,
            _interestRate,
            _interestAmount,
            _paymentCount,
            _timelap
        );
        emit LoanCreated(
            nftIDS[0],
            nftIDS[1],
            assetAddresses[0],
            address(newLoan)
        );
        
        return address(newLoan);
     }
}
