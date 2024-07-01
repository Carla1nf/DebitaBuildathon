pragma solidity ^0.8.0;

import "./DebitaV2Loan.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDebitaOfferFactory {
    function isSenderAnOffer(address sender) external returns (bool);

    function isContractVeNFT(address contractAddress) external view returns (bool);
}

contract DebitaV2LoanFactory is ReentrancyGuard {
    event updatedLoan(address indexed loanAddress, string _type);
    event LoanCreated(
        address indexed lendingAddress, address indexed loanAddress, uint256 lenderId, uint256 borrowerId
    );

    address public feeAddress;

    // ADDRESS => IS LOAN
    mapping(address => bool) public isSenderALoan;
    mapping(uint256 => address) public NftID_to_LoanAddress;

    address owner;
    uint256 public feeOffer = 8;
    uint256 public feeInterestLoan = 12;
    address private debitaOfferFactory;
    address private ownershipAddress;

    constructor() {
        owner = msg.sender;
        feeAddress = msg.sender;
    }

    modifier onlyOffers() {
        require(
            IDebitaOfferFactory(debitaOfferFactory).isSenderAnOffer(msg.sender), "Only offers can call this function."
        );
        _;
    }


    modifier onlyLoans() {
        require(isSenderALoan[msg.sender], "Only loans");
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only offers can call this function.");
        _;
    }

    function createLoanV2(
        uint256[2] calldata nftIDS,
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
        emit LoanCreated(assetAddresses[0], address(newLoan), nftIDS[0], nftIDS[1]);

        return address(newLoan);
    }

    // owners[0] = lender, owners[1] = borrower
    function mintOwnerships(address[2] calldata owners) external onlyOffers returns (uint256[2] memory) {
        uint256[2] memory nftIDS;
        for (uint256 i = 0; i < 2; i++) {
            nftIDS[i] = IOwnerships(ownershipAddress).mint(owners[i]);
        }
        return nftIDS;
    }

    function setMappingIdToLoan(address loanAddress, uint256[2] calldata nftIds) public onlyOffers {
        NftID_to_LoanAddress[nftIds[0]] = loanAddress;
        NftID_to_LoanAddress[nftIds[1]] = loanAddress;
    }

    function setOwnershipAddress(address ownershipAdd) public onlyOwner {
        require(ownershipAddress == address(0x0), "Already init");
        ownershipAddress = ownershipAdd;
    }

    function setDebitaOfferFactory(address offerFactory) public onlyOwner {
        require(debitaOfferFactory == address(0x0), "Already init");
        debitaOfferFactory = offerFactory;
    }

    function setFeeAddress(address _newAdd) public onlyOwner {
        feeAddress = _newAdd;
    }

    //  _fee / 1000
    function setOfferFee(uint256 _fee) public onlyOwner {
        require(15 >= _fee && _fee >= 5);
        feeOffer = _fee;
    }

    //  _fee / 100
    function setInterestFee_Loan(uint256 _fee) public onlyOwner {
        require(20 >= _fee && _fee >= 7);
        feeInterestLoan = _fee;
    }

    /*  VIEW FUNCTIONS  */

    function getAddressById(uint256 id) public view returns (address) {
        return NftID_to_LoanAddress[id];
    }

    function checkIfAddressIsveNFT(address contractAddress) public view returns (bool) {
        return IDebitaOfferFactory(debitaOfferFactory).isContractVeNFT(contractAddress);
    }
     
    function transferOwnership(address _newAddress) public onlyOwner() {
        owner = _newAddress;
    }


    // rewardsClaimed, collateralClaimed
    function emitUpdated(string memory _type) public onlyLoans {
        emit updatedLoan(msg.sender, _type);
    }

    
    
}
