pragma solidity ^0.8.0;

import "./DebitaV2Loan.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDebitaOfferFactory {
    function isSenderAnOffer(address sender) external returns (bool);
}



contract DebitaV2LoanFactory is ReentrancyGuard {
      event LoanCreated(
        address indexed lendingAddress,
        address indexed loanAddress,
        uint lenderId,
        uint borrowerId
    );

    address public feeAddress;


    mapping(address => bool) public isSenderALoan;
    address owner;
    address private debitaOfferFactory;
    address private ownershipAddress;


    constructor() {
        owner = msg.sender;
        feeAddress = msg.sender;
    }

    modifier onlyOffers() {
        require(
            IDebitaOfferFactory(debitaOfferFactory).isSenderAnOffer(msg.sender),
            "Only offers can call this function."
        );
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only offers can call this function.");
        _;
    }


   function createLoanV2(
        uint[2] calldata nftIDS,
        address[2] calldata assetAddresses,
        uint256[2] calldata assetAmounts,
        bool[2] calldata isAssetNFT,
        uint32[3] calldata loanData, // [0] = interestRate, [1] = _paymentCount, [2] = _timelap
        uint256[3] calldata nftData,
        address interest_address,
        address offer_address
    ) public onlyOffers nonReentrant returns (address) {
        DebitaV2Loan newLoan = new DebitaV2Loan(
            nftIDS,
            assetAddresses,
            assetAmounts,
            isAssetNFT,
            loanData[0],
            nftData,
            loanData[1],
            loanData[2],
            ownershipAddress,
            [address(this), offer_address],
            interest_address
        );
        isSenderALoan[address(newLoan)] = true;
        emit LoanCreated(
            assetAddresses[0],
            address(newLoan),
            nftIDS[0],
            nftIDS[1]
        );

        return address(newLoan);
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

    // owners[0] = lender, owners[1] = borrower
    function mintOwnerships(
        address[2] calldata owners
    ) external onlyOffers returns (uint[2] memory) {
        uint[2] memory nftIDS;
        for (uint i = 0; i < 2; i++) {
            nftIDS[i] = IOwnerships(ownershipAddress).mint(owners[i]);
        }
        return nftIDS;
    }

    function setOwnershipAddress(address ownershipAdd) public onlyOwner {
        ownershipAddress = ownershipAdd;
    }

    function setDebitaOfferFactory(address offerFactory) public onlyOwner {
        debitaOfferFactory = offerFactory;
    }


}