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
        address indexed lendingAddress,
        address indexed loanAddress,
        uint lenderId,
        uint borrowerId
    );

    address owner;
    address public feeAddress;
    address ownershipAddress;
    mapping(address => address) public voterEachveNft;
    mapping(address => bool) public isSenderAnOffer;
    mapping(address => bool) public isSenderALoan;

    modifier onlyOffers() {
        require(
            isSenderAnOffer[msg.sender],
            "Only offers can call this function."
        );
        _;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Only offers can call this function.");
        _;
    }

    constructor() {
        feeAddress = msg.sender;
        owner = msg.sender;
    }

    // interestRate (1 ==> 0.01%, 1000 ==> 10%, 10000 ==> 100%)
    function createOfferV2(
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory isAssetNFT,
        uint8 _interestRate,
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
            isAssetNFT[0] && assetAmounts[0] > 1 
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
            ERC20(assetAddress).transferFrom(from, to, assetAmount);
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
}
