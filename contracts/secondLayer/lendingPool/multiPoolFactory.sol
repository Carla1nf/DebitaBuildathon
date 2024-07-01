pragma solidity ^0.8.0;

import "./debitaMultiPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract debitaMultiPoolFactory {
    event CreatePool(address indexed _add);

    mapping(address => bool) public isSenderAPool;
    mapping(address => address) public getOraclePerToken;

    address owner;
    address public ownershipContract;
    address public auctionFactory;
    address public offerFactory;
    address public loanFactory;

    modifier onlyOwner() {
        require(owner == msg.sender, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPool(
        address collateralToken,
        address principleToken,
        uint ltv,
        uint interest,
        uint loanDuration,
        uint initCollateralAmount
    ) public {
        require(
            getOraclePerToken[collateralToken] != address(0x0) &&
                getOraclePerToken[principleToken] != address(0x0),
            "An oracle is not set"
        );

        debitaMultiPool newPool = new debitaMultiPool(
            ltv,
            interest,
            loanDuration,
            initCollateralAmount,
            collateralToken,
            principleToken,
            address(this)
        );

        SafeERC20.safeTransferFrom(
            ERC20(collateralToken),
            msg.sender,
            address(newPool),
            initCollateralAmount
        );

        isSenderAPool[address(newPool)] = true;

        emit CreatePool(address(newPool));
    }

    function setOwnership(address _ownershipContract) public onlyOwner {
        require(ownershipContract != address(0x0), "Invalid address");
        ownershipContract = _ownershipContract;
    }

    function setDebitaOfferFactory(address _offerFactory) public onlyOwner {
        require(_offerFactory != address(0x0), "Invalid address");
        offerFactory = _offerFactory;
    }

    function setDebitaLoanFactory(address _loanFactory) public onlyOwner {
        require(_loanFactory != address(0x0), "Invalid address");
        loanFactory = _loanFactory;
    }

    function setAuctionFactory(address _auctionFactory) public onlyOwner {
        require(_auctionFactory != address(0x0), "Invalid address");
        loanFactory = _auctionFactory;
    }

    function setOraclePerToken(address token, address oracle) public onlyOwner {
        getOraclePerToken[token] = oracle;
    }
}
