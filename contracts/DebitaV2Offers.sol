pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface IDebitaOfferFactoryV2 {
    function debitaLoanFactoryV2() external returns (address);
}

interface IDebitaFactoryV2 is IERC721Receiver {   


    function mintOwnerships(
        address[2] calldata owners
    ) external returns (uint[2] memory);

    function createLoanV2(
        uint[2] calldata nftIDS,
        address[2] calldata assetAddresses,
        uint256[2] calldata assetAmounts,
        bool[2] calldata isAssetNFT,
        uint32[3] calldata loanData, // [0] = interestRate, [1] = _paymentCount, [2] = _timelap
        uint256[3] calldata nftData,
        address interest_address,
        address offer_address
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
        uint[3] nftData; // [0]: the id of the NFT that the owner transfered here (could be borrower or lender) in case lending/borrowing is NFT else 0 [1]: value of veNFT (0 if not veNFT) [2]: interest Amount
        uint8 paymentCount;
        uint32 _timelap;
        bool isLending;
        bool isPerpetual;
        bool isActive;
        address interest_address; // in case lending is NFT else 0
    }

    OfferInfo private storage_OfferInfo;

    address public immutable owner;
    address public debitaFactoryLoansV2;
    address private immutable debitaFactoryOfferV2;
    uint private totalLending;
    uint private totalCollateral;
    uint lastEditedBlock;

    mapping(address => bool) private isSenderALoan;

    modifier afterCooldown() {
        require(
            block.timestamp - lastEditedBlock > 5 minutes,
            "Cooldown time is not over yet."
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyActive() {
        require(storage_OfferInfo.isActive, "Offer is not active.");
        _;
    }

    modifier onlyLoans() {
        require(
            isSenderALoan[msg.sender],
            "Only loans can call this function."
        );
        _;
    }

    constructor(
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory isAssetNFT,
        uint16 _interestRate,
        uint[3] memory _nftData, // In case of NFT, nftData[0] = nftID, nftData[1] = value of veNFT (0 if not veNFT) nfData[2] = interest Amount, nfData[3] = interest
        uint8 _paymentCount,
        uint32 _timelap,
        bool isLending,
        bool perpetual,
        address _owner,
        address interest_address
    ) {
        storage_OfferInfo = OfferInfo({
            assetAddresses: assetAddresses,
            assetAmounts: assetAmounts,
            isAssetNFT: isAssetNFT,
            interestRate: _interestRate,
            nftData: _nftData,
            paymentCount: _paymentCount,
            _timelap: _timelap,
            isLending: isLending,
            isPerpetual: perpetual,
            isActive: true,
            interest_address: interest_address
        });
        owner = _owner;
        debitaFactoryLoansV2 = IDebitaOfferFactoryV2(msg.sender).debitaLoanFactoryV2();
        totalLending = assetAmounts[0];
        totalCollateral = assetAmounts[1];
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
            m_offer.isAssetNFT[index],
            m_offer.nftData[0]
        );
    }

    // 10 = 1% from the totalAmount
    function acceptOfferAsBorrower(
        uint amount,
        uint sendingNFTID
    ) public nonReentrant onlyActive afterCooldown {
        OfferInfo memory m_offer = storage_OfferInfo;
        uint porcentage = (amount * 1000) / m_offer.assetAmounts[0];
        require(m_offer.isLending, "Owner is not lender");
        require(porcentage <= 1000 && porcentage >= 10, "100% - 1%");
        require(m_offer.isActive, "Offer is not active");

        // [0]: Lending  [1]: Collateral
        uint256 collateralAmount = (m_offer.assetAmounts[1] * porcentage) /
            1000;

        m_offer.assetAmounts[0] -= amount;
        m_offer.assetAmounts[1] -= collateralAmount;

        if (m_offer.assetAmounts[0] == 0) {
            storage_OfferInfo.isActive = false;
        }

        transferAssets(
            msg.sender,
            address(this),
            m_offer.assetAddresses[1],
            collateralAmount,
            m_offer.isAssetNFT[1],
            sendingNFTID
        );
        storage_OfferInfo = m_offer;

        uint[2] memory ids = IDebitaFactoryV2(debitaFactoryLoansV2).mintOwnerships(
            [owner, msg.sender]
        );
        address loanAddress = IDebitaFactoryV2(debitaFactoryLoansV2).createLoanV2(
            ids,
            m_offer.assetAddresses,
            [amount, collateralAmount],
            m_offer.isAssetNFT,
            [m_offer.interestRate, m_offer.paymentCount, m_offer._timelap],
            [m_offer.nftData[0], sendingNFTID, m_offer.nftData[2]],
            m_offer.interest_address,
            address(this)
        );
        isSenderALoan[loanAddress] = true;
        // Send collateral to loanAddress
        transferAssets(
            address(this),
            address(loanAddress),
            m_offer.assetAddresses[1],
            collateralAmount,
            m_offer.isAssetNFT[1],
            sendingNFTID
        );

        // Transfer tokens to the borrower
        transferAssets(
            address(this),
            msg.sender,
            m_offer.assetAddresses[0],
            amount,
            m_offer.isAssetNFT[0],
            m_offer.nftData[0]
        );
    }

    function acceptOfferAsLender(
        uint amount,
        uint sendingNFTID
    ) public nonReentrant onlyActive afterCooldown {
        OfferInfo memory m_offer = storage_OfferInfo;
        uint porcentage = (amount * 1000) / m_offer.assetAmounts[0];
        require(!m_offer.isLending, "Owner is not borrower");
        require(porcentage <= 1000 && porcentage >= 10, "100% - 1%");
        require(m_offer.isActive, "Offer is not active");

        if (m_offer.isAssetNFT[0] || m_offer.isAssetNFT[1]) {
            require(porcentage == 1000, "Must be 100%");
        }

        uint256 collateralAmount = (m_offer.assetAmounts[1] * porcentage) /
            1000;

        m_offer.assetAmounts[0] -= amount;
        m_offer.assetAmounts[1] -= collateralAmount;

        if (m_offer.assetAmounts[0] == 0) {
            storage_OfferInfo.isActive = false;
        }

        // Sending Lending Assets to contract
        transferAssets(
            msg.sender,
            address(this),
            m_offer.assetAddresses[0],
            amount,
            m_offer.isAssetNFT[0],
            sendingNFTID
        );
        storage_OfferInfo = m_offer;

        uint[2] memory ids = IDebitaFactoryV2(debitaFactoryLoansV2).mintOwnerships(
            [msg.sender, owner]
        );

        address loanAddress = IDebitaFactoryV2(debitaFactoryLoansV2).createLoanV2(
            ids,
            m_offer.assetAddresses,
            [amount, collateralAmount],
            m_offer.isAssetNFT,
            [m_offer.interestRate, m_offer.paymentCount, m_offer._timelap],
            [sendingNFTID, m_offer.nftData[0], m_offer.nftData[2]],
            m_offer.interest_address,
            address(this)
        );
        isSenderALoan[loanAddress] = true;

        // Send collateral to loanAddress
        transferAssets(
            address(this),
            address(loanAddress),
            m_offer.assetAddresses[1],
            collateralAmount,
            m_offer.isAssetNFT[1],
            m_offer.nftData[0]
        );

        // Transfer tokens to the borrower
        transferAssets(
            address(this),
            owner,
            m_offer.assetAddresses[0],
            amount,
            m_offer.isAssetNFT[0],
            sendingNFTID
        );
    }

    function insertAssets(uint assetAmount) public onlyLoans nonReentrant {
        OfferInfo memory m_offer = storage_OfferInfo;
        address assetAddress = m_offer.isLending
            ? m_offer.assetAddresses[0]
            : m_offer.assetAddresses[1];

        transferAssets(
            msg.sender,
            address(this),
            assetAddress,
            assetAmount,
            m_offer.isAssetNFT[m_offer.isLending ? 0 : 1],
            m_offer.nftData[0]
        );

        m_offer.assetAmounts[m_offer.isLending ? 0 : 1] += assetAmount;

        uint amountOfAssetAdded = m_offer.isLending
            ? totalLending
            : totalCollateral;
        uint porcentageToAdd = (assetAmount * 10000000) / amountOfAssetAdded;

        // Add the opposite asset
        uint oppositeOfAmountAsset = m_offer.isLending
            ? totalCollateral
            : totalLending;
        m_offer.assetAmounts[m_offer.isLending ? 1 : 0] +=
            (oppositeOfAmountAsset * porcentageToAdd) /
            10000000;

        storage_OfferInfo = m_offer;
    }

// ----- TEST IT -----
// _newLoanData: [0] = interestRate, [1] = _paymentCount, [2] = _timelap
// _newAssetAmounts: [0] = lendingAmount, [1] = collateralAmount
    function editOffer(
        uint[2] calldata _newAssetAmounts,
        uint[3] calldata _newLoanData,
        uint veValue,
        uint _newInterestRateForNFT
    ) public onlyOwner() {
        OfferInfo memory m_offer = storage_OfferInfo;
        uint index = m_offer.isLending ? 0 : 1;
        lastEditedBlock = block.timestamp;
        if(
            _newLoanData[2] < 1 days || 
            _newLoanData[2] > 365 days ||
            _newAssetAmounts[0] == 0 ||
            _newLoanData[1] > 10 ||
            _newLoanData[1] == 0 ||
            _newLoanData[1] > _newAssetAmounts[0] ||
            _newLoanData[0] > 10000 || 
            m_offer.isAssetNFT[0] && _newLoanData[1] > 1 ||
            m_offer.isAssetNFT[0] && _newAssetAmounts[0] > 1 ||
            m_offer.isAssetNFT[1] && _newAssetAmounts[1] > 1 
        ) {
            revert();
        }
      
        address depositedAddress =  m_offer.assetAddresses[index];
        uint256 depositedAmount = m_offer.assetAmounts[index];

        if (m_offer.isAssetNFT[index]) {
            m_offer.nftData[1] = veValue;
            m_offer.nftData[2] = _newInterestRateForNFT;
            
        } else {
          transferAssets(address(this), msg.sender, depositedAddress, depositedAmount, false, 0);
        }
        



        m_offer.assetAmounts[0] = _newAssetAmounts[0];
        m_offer.assetAmounts[1] = _newAssetAmounts[1];
        m_offer.interestRate = uint16(_newLoanData[0]);
        m_offer.paymentCount = uint8(_newLoanData[1]);
        m_offer._timelap = uint32(_newLoanData[2]);


        storage_OfferInfo = m_offer;

        if(!m_offer.isAssetNFT[index]) {
            transferAssets(msg.sender, address(this), depositedAddress, _newAssetAmounts[index], false, 0);
        }
      
    }

    function getOffersData() public view returns (OfferInfo memory) {
        return storage_OfferInfo;
    }

    function transferAssets(
        address from,
        address to,
        address assetAddress,
        uint256 assetAmount,
        bool isNFT,
        uint nftID // 0 IF NOT NFT
    ) internal {
        if (isNFT) {
            ERC721(assetAddress).transferFrom(from, to, nftID);
        } else {
            if (from == address(this)) {
                ERC20(assetAddress).transfer(to, assetAmount);
            } else {
                ERC20(assetAddress).transferFrom(from, to, assetAmount);
            }
        }
    }
}
