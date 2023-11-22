pragma solidity ^0.8.0;

contract DebitaV2Loan {

    uint256 immutable lenderID;
    uint256 immutable borrowerID;
    address immutable lendingAddress;
    address immutable collateralAddress;
    uint256 immutable lendingAmount;
    uint256 immutable collateralAmount;
    bool immutable isLendingNFT;
    bool immutable isCollateralNFT;
    uint immutable interestRate;
    uint immutable interestAmount;
    uint256 immutable paymentCount;
    uint immutable timelap;
    uint nextDeadLine;
    uint totalDeadLine;
    bool executed;
    uint256  paidCount;

    constructor (
        uint256 _lenderID,
        uint256 _borrowerID,
        address _lendingAddress,
        address _collateralAddress,
        uint256 _lendingAmount,
        uint256 _collateralAmount,
        bool _isLendingNFT,
        bool _isCollateralNFT,
        uint _interestRate,
        uint _interestAmount,
        uint256 _paymentCount,
        uint _timelap
     )  {
        lenderID = _lenderID;
        borrowerID = _borrowerID;
        lendingAddress = _lendingAddress;
        collateralAddress = _collateralAddress;
        lendingAmount = _lendingAmount;
        collateralAmount = _collateralAmount;
        isLendingNFT = _isLendingNFT;
        isCollateralNFT = _isCollateralNFT;
        interestRate = _interestRate;
        interestAmount = _interestAmount;
        paymentCount = _paymentCount;
        timelap = _timelap;
        nextDeadLine = block.timestamp + _timelap;
        totalDeadLine = block.timestamp + (_timelap * _paymentCount);
    }
}