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
        uint256 interestAmount_Lending_NFT; // only if the lending is an NFT
        uint256 timelap; // timelap on each payment
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
    uint constant interestFEE = 6;
    uint public claimableAmount;

    // interestRate (1 ==> 0.01%, 1000 ==> 10%, 10000 ==> 100%)
    constructor(
        uint[2] memory nftIDS,
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory _isAssetNFT,
        uint _interestRate,
        uint _interestAmount,
        uint8 _paymentCount,
        uint _timelap,
        address _ownershipContract, // contract address for the ownerships
        address debitaV2, // contract address of DebitaV2Factory
        address interest_address // 0x0 if lending is not NFT
    ) {
        uint totalAmountToPay = assetAmounts[0] +
            ((assetAmounts[0] * _interestRate) / 10000);

        storage_loanInfo = LoanData({
            IDS: nftIDS,
            assetAddresses: assetAddresses,
            assetAmounts: assetAmounts,
            isAssetNFT: _isAssetNFT,
            interestAmount_Lending_NFT: _interestAmount / _paymentCount,
            timelap: _timelap,
            interestAddress_Lending_NFT: interest_address,
            paymentCount: _paymentCount,
            paymentsPaid: 0,
            paymentAmount: totalAmountToPay / _paymentCount,
            deadline: block.timestamp + (_timelap * _paymentCount),
            deadlineNext: block.timestamp + _timelap,
            executed: false
        });
        ownershipContract = _ownershipContract;
        debitaFactoryV2 = debitaV2;
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
            fee = (loan.interestAmount_Lending_NFT * interestFEE) / 100;
            claimableAmount += loan.interestAmount_Lending_NFT - fee;
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
                loan.interestAmount_Lending_NFT,
                fee,
                _feeAddress
            );

            transferAssets(
                msg.sender,
                address(this),
                loan.assetAddresses[0],
                loan.paymentAmount,
                loan.isAssetNFT[0]
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
        uint fee = (m_loan.assetAmounts[1] * 2) / 100;

        transferAssets(
            address(this),
            msg.sender,
            m_loan.assetAddresses[1],
            m_loan.assetAmounts[1] - fee,
            false
        );
        transferAssets(
            address(this),
            _feeAddress,
            m_loan.assetAddresses[1],
            fee,
            false
        );
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
            m_loan.isAssetNFT[1]
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

        transferAssets(address(this), msg.sender, tokenAddress, amount, false);

        if (m_loan.isAssetNFT[0]) {
            transferAssets(
                address(this),
                msg.sender,
                m_loan.assetAddresses[0],
                m_loan.paymentAmount,
                true
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
        bool isNFT
    ) internal {
        if (isNFT) {
            ERC721(assetAddress).transferFrom(from, to, assetAmount);
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
