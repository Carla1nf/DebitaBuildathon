pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IOwnerships {
    function ownerOf(uint id) external returns (address);

    function mint(address to) external returns (uint256);

    function burn(uint256 tokenId) external;
}

interface IDebitaFactory {
    function feeAddress() external returns (address);
}

contract DebitaV2Loan is ReentrancyGuard {
    event debtPaid(uint indexed paymentCount, uint indexed paymentPaid);
    event collateralClaimed(address indexed claimer);

    struct LoanData {
        uint[2] IDS; // 0: Lender, 1: Borrower
        address[2] assetAddresses; // 0: Lending, 1: Collateral
        uint256[2] assetAmounts; // 0: Lending, 1: Collateral
        bool[2] isAssetNFT; // 0: Lending, 1: Collateral
        uint256[3] nftData; // [0]: NFT ID Lender, [1] NFT ID Collateral, [2] Amount of interest (If lending is NFT) ---  0 on each if not NFT
        uint32 timelap; // timelap on each payment
        address interestAddress_Lending_NFT; // only if the lending is an NFT
        uint8 paymentCount;
        uint8 paymentsPaid;
        uint256 paymentAmount;
        uint256 deadline;
        uint256 deadlineNext;
        bool executed; // if collateral claimed
    }

    LoanData storage_loanInfo;
    address ownershipContract;
    address debitaFactoryV2;
    address debitaOfferV2;
    uint constant interestFEE = 6;
    uint public claimableAmount;

    // interestRate (1 ==> 0.01%, 1000 ==> 10%, 10000 ==> 100%)
    constructor(
        uint[2] memory nftIDS,
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory _isAssetNFT,
        uint32 _interestRate,
        uint[3] memory nftsData,
        uint32 _paymentCount,
        uint32 _timelap,
        address _ownershipContract, // contract address for the ownerships
        address[2] memory debitaAddresses , // contract address of DebitaV2Factory & offers address
        address interest_address // 0x0 if lending is not NFT
    ) {
        uint totalAmountToPay = assetAmounts[0] +
            ((assetAmounts[0] * _interestRate) / 10000);

        storage_loanInfo = LoanData({
            IDS: nftIDS,
            assetAddresses: assetAddresses,
            assetAmounts: assetAmounts,
            isAssetNFT: _isAssetNFT,
            nftData: nftsData,
            timelap: _timelap,
            interestAddress_Lending_NFT: interest_address,
            paymentCount: uint8(_paymentCount),
            paymentsPaid: 0,
            paymentAmount: totalAmountToPay / _paymentCount,
            deadline: block.timestamp + (_timelap * _paymentCount),
            deadlineNext: block.timestamp + _timelap,
            executed: false
        });
        ownershipContract = _ownershipContract;
        debitaFactoryV2 = debitaAddresses[0];
        debitaOfferV2 = debitaAddresses[1];
    }

    /* 
    -------- -------- -------- -------- -------- -------- -------- 
           LOGICAL FUNCTIONS
    -------- -------- -------- -------- -------- -------- -------- 
    
    */
    function payDebt() public nonReentrant {
        LoanData memory loan = storage_loanInfo;
        IOwnerships ownerContract = IOwnerships(ownershipContract);

        // Check conditions for valid debt payment
        // Revert the transaction if any condition fail

        // 1. Check if the loan final deadline has passed
        // 2. Check if the sender is the owner of the collateral associated with the loan
        // 3. Check if all payments have been made for the loan
        // 4. Check if the loan collateral has already been executed
        if (
            loan.deadline < block.timestamp ||
            ownerContract.ownerOf(loan.IDS[1]) != msg.sender ||
            loan.paymentsPaid == loan.paymentCount ||
            loan.executed == true
        ) {
            revert();
        }

        uint fee;
        if (loan.isAssetNFT[0]) {
            fee = (loan.nftData[2] * interestFEE) / 100;
            claimableAmount += loan.nftData[2] - fee;
        } else {
            uint interestPerPayment = ((loan.paymentAmount *
                loan.paymentCount) - loan.assetAmounts[0]) / loan.paymentCount;
            fee = (interestPerPayment * interestFEE) / 100;
            claimableAmount += loan.paymentAmount - fee;
        }

        loan.paymentsPaid += 1;
        loan.deadlineNext += loan.timelap;
        storage_loanInfo = loan;
        address _feeAddress = IDebitaFactory(debitaFactoryV2).feeAddress();

        // If lending is NFT -- get interest from interestAmount_Lending_NFT
        if (loan.isAssetNFT[0]) {
            transferAssetHerewithFee(
                msg.sender,
                loan.interestAddress_Lending_NFT,
                loan.nftData[2],
                fee,
                _feeAddress
            );

            transferAssets(
                msg.sender,
                address(this),
                loan.assetAddresses[0],
                1,
                loan.isAssetNFT[0],
                loan.nftData[0]
            );
        } else {
            transferAssetHerewithFee(
                msg.sender,
                loan.assetAddresses[0],
                loan.paymentAmount,
                fee,
                _feeAddress
            );
        }

        emit debtPaid(loan.paymentCount, loan.paymentsPaid);
    }

    function claimCollateralasLender() public nonReentrant {
        LoanData memory m_loan = storage_loanInfo;
        IOwnerships _ownerContract = IOwnerships(ownershipContract);
        // 1. Check if the sender is the owner of the lender's NFT
        // 2. Check if the deadline for the next payment has passed
        // 3. Check if all payments have been made for the loan
        // 4. Check if the loan has already been executed
        if (
            _ownerContract.ownerOf(m_loan.IDS[0]) != msg.sender ||
            m_loan.deadlineNext > block.timestamp ||
            m_loan.paymentCount == m_loan.paymentsPaid ||
            m_loan.executed == true
        ) {
            revert();
        }

        _ownerContract.burn(m_loan.IDS[0]);
        // Mark the loan as executed
        storage_loanInfo.executed = true;
        address _feeAddress = IDebitaFactory(debitaFactoryV2).feeAddress();
        
        // If lending is nft, to claim the NFT collateral, the lender must pay 20% of the interest, otherwise 2% of the lending.
       if(m_loan.isAssetNFT[1]) {
         uint feeAmount = m_loan.isAssetNFT[0] ? 20 : 2;
         uint amount = m_loan.isAssetNFT[0] ? m_loan.nftData[2] : m_loan.assetAmounts[0];
         address feeToken = m_loan.isAssetNFT[0] ? m_loan.interestAddress_Lending_NFT : m_loan.assetAddresses[0]; 
         uint fee = (amount * feeAmount) / 100;

         // Sending Fee and then collateral
         transferAssets(msg.sender, _feeAddress, feeToken, fee, false, 0);
         transferAssets(address(this), msg.sender, m_loan.assetAddresses[1], m_loan.assetAmounts[1], true, m_loan.nftData[1]);
        } else {
            uint fee = (m_loan.assetAmounts[1] * 2) / 100;
            transferAssets(address(this), _feeAddress, m_loan.assetAddresses[1], fee, false, 0);
            transferAssets(
                address(this),
                msg.sender,
                m_loan.assetAddresses[1],
                m_loan.assetAmounts[1] - fee,
                m_loan.isAssetNFT[1],
                m_loan.nftData[1]
            );
        }
        emit collateralClaimed(msg.sender);
    }

    function claimCollateralasBorrower() public nonReentrant {
        LoanData memory m_loan = storage_loanInfo;
        IOwnerships _ownerContract = IOwnerships(ownershipContract);
        // 1. Check if the sender is the owner of the borrowers's NFT
        // 2. Check if the paymenyCount is different than the paids
        // 3. Check if the loan has already been executed
        if (
            _ownerContract.ownerOf(m_loan.IDS[1]) != msg.sender ||
            m_loan.paymentCount != m_loan.paymentsPaid ||
            m_loan.executed == true
        ) {
            revert();
        }

        storage_loanInfo.executed = true;

        // Burn msg.sender NFT
        _ownerContract.burn(m_loan.IDS[1]);

        transferAssets(
            address(this),
            msg.sender,
            m_loan.assetAddresses[1],
            m_loan.assetAmounts[1],
            m_loan.isAssetNFT[1],
            m_loan.nftData[1]
        );

        emit collateralClaimed(msg.sender);
    }

    function claimDebt() public nonReentrant {
        LoanData memory m_loan = storage_loanInfo;
        IOwnerships _ownerContract = IOwnerships(ownershipContract);
        uint amount = claimableAmount;

        // 1. Check if the sender is the owner of the lender's NFT
        // 2. Check if there is an amount available to claim
        if (
            _ownerContract.ownerOf(m_loan.IDS[0]) != msg.sender || amount == 0
        ) {
            revert();
        }

        // Delete the claimable debt amount for the lender
        delete claimableAmount;

        // If its the last payment, burn the lender's NFT
        if (m_loan.paymentCount == m_loan.paymentsPaid) {
            _ownerContract.burn(m_loan.IDS[0]);
        }

        address tokenAddress = m_loan.isAssetNFT[0]
            ? m_loan.interestAddress_Lending_NFT
            : m_loan.assetAddresses[0];

        transferAssets(address(this), msg.sender, tokenAddress, amount, false, 0);

        if (m_loan.isAssetNFT[0]) {
            transferAssets(
                address(this),
                msg.sender,
                m_loan.assetAddresses[0],
                m_loan.paymentAmount,
                true,
                m_loan.nftData[0]
            );
        }
    }

    /* 
    -------- -------- -------- -------- -------- -------- -------- 
           INTERNAL FUNCTIONS
    -------- -------- -------- -------- -------- -------- -------- 
    
    */
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
            if (from == address(this)) {
                ERC20(assetAddress).transfer(to, assetAmount);
            } else {
                ERC20(assetAddress).transferFrom(from, to, assetAmount);
            }
        }
    }

    function transferAssetHerewithFee(
        address from,
        address assetAddress,
        uint256 assetAmount,
        uint256 fee,
        address feeAddress
    ) internal {
        ERC20(assetAddress).transferFrom(from, address(this), assetAmount);
        ERC20(assetAddress).transfer(feeAddress, fee);
    }

    /* 
    -------- -------- -------- -------- -------- -------- -------- 
           VIEW FUNCTIONS
    -------- -------- -------- -------- -------- -------- -------- 
    
    */

    function getLoanData() public view returns (LoanData memory) {
        return storage_loanInfo;
    }
}
