pragma solidity ^0.8.0;

contract DebitaV2Loan {

    uint256 public immutable lenderID;
    uint256 public immutable borrowerID;
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
        uint[2] memory nftIDS,
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool _isLendingNFT,
        bool _isCollateralNFT,
        uint _interestRate,
        uint _interestAmount,
        uint256 _paymentCount,
        uint _timelap
     )  {
        lenderID = nftIDS[0];
        borrowerID = nftIDS[1];
        lendingAddress = assetAddresses[0];
        collateralAddress = assetAddresses[1];
        lendingAmount = assetAmounts[0];
        collateralAmount = assetAmounts[1];
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