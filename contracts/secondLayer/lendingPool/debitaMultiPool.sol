pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./dToken.sol";

interface auctionFactory {
    function isAuction(address auction) external view returns (bool);
    function createAuction(
        uint _veNFTID,
        address _veNFTAddress,
        address liquidationToken,
        uint _initAmount,
        uint _floorAmount,
        uint _duration
    ) external returns (address);
}

interface Auction {
    struct dutchAuction_INFO {
        uint nftCollateralID;
        address sellingToken;
        uint initAmount;
        uint floorAmount;
        uint duration;
        uint endBlock;
        uint tickPerBlock;
        bool isActive;
        uint initialBlock;
        bool isLiquidation;
    }

    function s_CurrentAuction()
        external
        view
        returns (dutchAuction_INFO memory);
}

interface IdebitaMultiPoolFactory {
    function auctionFactory() external view returns (address);
    function ownershipContract() external view returns (address);
    function getOraclePerToken(address token) external view returns (address);
    function offerFactory() external view returns (address);
    function loanFactory() external view returns (address);
}

interface DebitaOfferFactory {
    function createOfferV2(
        address[2] memory assetAddresses,
        uint256[2] memory assetAmounts,
        bool[2] memory isAssetNFT,
        uint16 _interestRate,
        uint256[2] calldata nftData,
        int128 veValue,
        uint8 _paymentCount,
        uint32 _timelap,
        bool[2] memory loanBooleans,
        address interest_address
    ) external returns (address);

    function isContractVeNFT(address _contract) external returns (bool);
    function isSenderAnOffer(address _sender) external returns (bool);
}

interface DebitaLoanFactory {
    function feeInterestLoan() external view returns (uint256);
}

interface DebitaOffer {
    struct OfferInfo {
        address[2] assetAddresses;
        uint256[2] assetAmounts;
        bool[2] isAssetNFT;
        uint16 interestRate;
        uint256[2] nftData; // [0]: the id of the NFT that the owner transfered here (could be borrower or lender) in case lending/borrowing is NFT else 0 , [1]: interest Amount
        int128 valueOfVeNFT; // only in case veNFT is in collateral
        uint8 paymentCount;
        uint32 _timelap; // time between payments
        bool isLending;
        bool isPerpetual; // offer goes back after paid
        bool isActive;
        address interest_address; // in case lending is NFT else 0
    }

    function acceptOfferAsBorrower(
        uint256 amount,
        uint256 sendingNFTID
    ) external returns (address, uint);

    function acceptOfferAsLender(
        uint256 amount,
        uint256 sendingNFTID
    ) external returns (address, uint);

    function getOffersData() external returns (OfferInfo memory);
}

interface DebitaLoan {
    function claimCollateralasLender() external;
    function claimDebt() external;
}

interface Ownerships {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface veSolid {
    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    function locked(uint256 id) external view returns (LockedBalance memory);
}

contract debitaMultiPool {
    event DepositPool(address user, uint amount);
    error SequencerDown();
    error GracePeriodNotOver();

    struct poolInfo {
        address collateralToken;
        address principleToken;
        address defaultToken;
        uint ltv;
        uint interest;
        uint duration;
    }

    struct dTokenData {
        uint depositedAmount;
        uint interestClaimedPerDepositedToken;
        uint defaultedClaimedPerDepositedToken;
        uint totalBorrowedAtDeposit;
        uint totalPaidAtDeposit;
        uint blockDeposit;
        bool Deadpoint;
    }

    struct dTokenInformation {
        uint depositedAmount;
        uint activeAmountBeingLent;
        uint expectedInterest;
        uint interestGenerated;
        uint interestClaimedPerDepositedToken;
        uint defaultToBeClaimed;
        uint defaultedClaimedPerDepositedToken;
        uint blockDeposit;
        bool Deadpoint;
    }

    struct loanInfo {
        uint lentAmount;
        uint expectedInterest;
        uint borrowerID;
        uint lenderID;
    }

    // ID => DATA
    mapping(uint => dTokenData) public allDTokensData;
    mapping(address => loanInfo) public allLoansInfo;

    poolInfo public s_pool;
    AggregatorV3Interface public dataFeed_Principle;
    AggregatorV3Interface public dataFeed_Collateral;
    AggregatorV2V3Interface public sequencerUptimeFeed;

    uint256 private constant GRACE_PERIOD_TIME = 3600;
    dToken dTokenContract;

    uint expectingInterestPerToken; // interest to be Paid per token deposited
    uint interestPaidPerToken; // already paid interest per token deposited

    uint borrowedAmountPerToken; // Total borrowed amount per token deposited
    uint paidAmountPerToken; // Total paid amount of borrowed amount per token deposited

    uint defaultedPerToken; // Total defaulted amount per token deposited

    uint totalBorrowed; // Total borrowed
    uint totalPaid; // Total paid
    uint totalDeposited; // Total tokens deposited
    uint totalDefaulted; // Total defaulted

    address poolFactoryAddress;

    constructor(
        uint ltv,
        uint interest,
        uint loanDuration,
        uint initCollateralAmount,
        address collateralToken,
        address principleToken,
        address poolFactory
    ) {
        s_pool = poolInfo({
            collateralToken: collateralToken,
            principleToken: principleToken,
            defaultToken: collateralToken,
            ltv: ltv,
            interest: interest,
            duration: loanDuration
        });

        address collateralOracle = IdebitaMultiPoolFactory(msg.sender)
            .getOraclePerToken(collateralToken);
        dataFeed_Collateral = AggregatorV3Interface(collateralOracle);

        address principleOracle = IdebitaMultiPoolFactory(msg.sender)
            .getOraclePerToken(principleToken);
        dataFeed_Principle = AggregatorV3Interface(principleOracle);

        // base sequencerCheck
        sequencerUptimeFeed = AggregatorV2V3Interface(
            0xBCF85224fc0756B9Fa45aA7892530B47e10b6433
        );

        poolFactoryAddress = poolFactory;
        dTokenContract = new dToken(address(this));
    }

    function acceptOffer(address offer) public {
        /* Calculate the collateral to put */
        uint priceCollateral = uint(getDataFeed_Collateral());
        uint pricePrinciple = uint(getDataFeed_Principle());
        DebitaOffer.OfferInfo memory offerData = DebitaOffer(offer)
            .getOffersData();
        poolInfo memory m_pool = s_pool;
        // check if sender is an offer
        require(
            DebitaOfferFactory(poolFactoryAddress).isSenderAnOffer(offer),
            "Not an offer"
        );

        // check params of the offer (should match with the pool params)
        require(
            !offerData.isLending &&
                offerData.assetAddresses[0] == m_pool.principleToken &&
                offerData.assetAddresses[1] == m_pool.collateralToken &&
                offerData.interestRate == m_pool.interest &&
                offerData._timelap == m_pool.duration &&
                offerData.paymentCount == 1,
            "Not lending"
        );

        // calculate ltv
        uint valuePrinciple = (pricePrinciple * offerData.assetAmounts[0]);
        uint collateralToPut = (valuePrinciple * m_pool.ltv) / 10000;

        DebitaOfferFactory offerFactory = DebitaOfferFactory(
            IdebitaMultiPoolFactory(poolFactoryAddress).offerFactory()
        );
        bool isCollateralANFT = offerFactory.isContractVeNFT(
            s_pool.collateralToken
        );

        // Check if collateral is veNFT
        if (isCollateralANFT) {
            veSolid veNFT = veSolid(s_pool.collateralToken);
            veSolid.LockedBalance memory locked = veNFT.locked(
                offerData.nftData[0]
            );
            uint valueCollateral = uint(int256(locked.amount)) *
                priceCollateral;
            require(
                locked.amount >= int128(int256(collateralToPut)),
                "Not enough locked"
            );
        } else {
            uint valueCollateral = (priceCollateral *
                offerData.assetAmounts[1]);
            require(
                valueCollateral >= collateralToPut,
                "Not enough collateral"
            );
        }

        (address loanAddress, uint borrowerID) = DebitaOffer(offer)
            .acceptOfferAsLender(offerData.assetAmounts[0], 0);

        allLoansInfo[loanAddress] = loanInfo({
            lentAmount: offerData.assetAmounts[0],
            expectedInterest: (offerData.assetAmounts[0] * m_pool.interest) /
                10000,
            borrowerID: borrowerID,
            lenderID: borrowerID - 1
        });
        uint feeInterestLoan = DebitaLoanFactory(
            IdebitaMultiPoolFactory(poolFactoryAddress).loanFactory()
        ).feeInterestLoan();
        uint interestToBePaid = (offerData.assetAmounts[0] -
            ((offerData.assetAmounts[0] * feeInterestLoan) / 100)) *
            m_pool.interest;
        totalBorrowed += offerData.assetAmounts[0];
        expectingInterestPerToken += interestToBePaid / totalDeposited;
        borrowedAmountPerToken += offerData.assetAmounts[0] / totalDeposited;
    }

    function claimDebt(address loanAddress) external {
        loanInfo memory loan = allLoansInfo[loanAddress];
        require(loan.lentAmount != 0, "Not lender");
        uint feeInterestLoan = DebitaLoanFactory(
            IdebitaMultiPoolFactory(poolFactoryAddress).loanFactory()
        ).feeInterestLoan();

        DebitaLoan(loanAddress).claimDebt();
        totalPaid += loan.lentAmount;
        interestPaidPerToken +=
            (loan.expectedInterest -
                ((loan.expectedInterest * feeInterestLoan) / 100)) /
            totalDeposited;
        paidAmountPerToken += loan.lentAmount / totalDeposited;
    }

    // function claimCollateral(address loanAddress) external {}

    function deposit(uint amount) public {
        SafeERC20.safeTransferFrom(
            ERC20(s_pool.principleToken),
            msg.sender,
            address(this),
            amount
        );
        uint porcentageBeingBorrowed = threeRule(
            totalDeposited,
            totalBorrowed - totalPaid
        );

        uint newPorcentageForOldStakers = threeRule(
            totalDeposited + amount,
            totalBorrowed - totalPaid
        );

        uint dilution = porcentageBeingBorrowed - newPorcentageForOldStakers;
        uint tokensDiluted = inverseThreeRule(totalDeposited, dilution);
        uint interestDiluted = (tokensDiluted * s_pool.interest) / 10000;

        // User "buys" other users position
        uint addInterestPaidPerToken = interestDiluted / totalDeposited;
        interestPaidPerToken += addInterestPaidPerToken;

        // Give back to the users tokens that were diluted
        paidAmountPerToken += tokensDiluted / totalDeposited;
        // We add the new deposited Amount
        totalDeposited += amount;

        uint id = dTokenContract.mintDToken(msg.sender);
        allDTokensData[id] = dTokenData({
            depositedAmount: amount - interestDiluted,
            interestClaimedPerDepositedToken: interestPaidPerToken,
            defaultedClaimedPerDepositedToken: defaultedPerToken,
            totalBorrowedAtDeposit: totalBorrowed,
            totalPaidAtDeposit: totalPaid,
            blockDeposit: block.number,
            Deadpoint: false
        });

        emit DepositPool(msg.sender, amount);
    }

    // function withdrawFromEndpoint(uint id, uint amount) external {}

    function forceWithdraw(uint id, uint amount) public {
        dTokenData memory dToken = allDTokensData[id];

        require(dToken.Deadpoint == false, "Deadpoint");
        require(dTokenContract.ownerOf(id) == msg.sender, "Not owner");
        require(
            dToken.depositedAmount >= amount,
            "You can't withdraw more than you deposited"
        );
        require(amount > 0, "Not 0");
        // claim interests before deleting
        claimDefault(id);
        claimInterests(id);

        totalDeposited -= amount;
        uint lentHole = (borrowedAmountPerToken -
            paidAmountPerToken -
            defaultedPerToken) * amount;

        allDTokensData[id].depositedAmount -= amount;
        uint idOfDeadPoint = dTokenContract.mintDToken(msg.sender);
        allDTokensData[idOfDeadPoint] = dTokenData({
            depositedAmount: lentHole,
            interestClaimedPerDepositedToken: interestPaidPerToken,
            defaultedClaimedPerDepositedToken: defaultedPerToken,
            totalBorrowedAtDeposit: totalBorrowed,
            totalPaidAtDeposit: totalPaid,
            blockDeposit: block.number,
            Deadpoint: true
        });

        SafeERC20.safeTransfer(
            ERC20(s_pool.principleToken),
            msg.sender,
            amount - lentHole
        );
    }

    // claim Default from the user perspective
    function claimDefault(uint id) public {
        require(dTokenContract.ownerOf(id) == msg.sender, "Not owner");
        dTokenData memory dToken = allDTokensData[id];
        if (dToken.defaultedClaimedPerDepositedToken == defaultedPerToken) {
            return;
        }

        uint claimableAmount = (defaultedPerToken -
            dToken.defaultedClaimedPerDepositedToken) * dToken.depositedAmount;
        allDTokensData[id]
            .defaultedClaimedPerDepositedToken = defaultedPerToken;
        SafeERC20.safeTransfer(
            ERC20(s_pool.defaultToken),
            msg.sender,
            claimableAmount
        );
    }

    // handle Default from the pool perspective
    function handleDefault(uint amount) public {
        IdebitaMultiPoolFactory poolFactory = IdebitaMultiPoolFactory(
            poolFactoryAddress
        );

        auctionFactory auctionFactoryContract = auctionFactory(
            poolFactory.auctionFactory()
        );

        require(auctionFactoryContract.isAuction(msg.sender), "Not auction");

        loanInfo memory loan = allLoansInfo[msg.sender];

        uint pricePrinciple = uint(getDataFeed_Principle());
        uint valuePrinciple = (pricePrinciple * loan.lentAmount) +
            (pricePrinciple * loan.expectedInterest);
        uint priceCollateral = uint(getDataFeed_Collateral());
        uint valueDefault = priceCollateral * amount;
        uint amountToTransfer;
        if (valueDefault > valuePrinciple) {
            try
                Ownerships(
                    IdebitaMultiPoolFactory((poolFactoryAddress))
                        .ownershipContract()
                ).ownerOf(loan.borrowerID)
            returns (address owner) {
                uint difference = valueDefault - valuePrinciple;
                amountToTransfer = difference / priceCollateral;
                SafeERC20.safeTransfer(
                    ERC20(s_pool.principleToken),
                    owner,
                    amountToTransfer
                );
            } catch {}
        }

        uint activeAmount = totalBorrowed - totalPaid;
        uint defaultPerTokenBeingLent = (amount - amountToTransfer) /
            activeAmount;
        defaultedPerToken += defaultPerTokenBeingLent;
        totalDefaulted += loan.lentAmount;
        totalPaid += loan.lentAmount;

        // handle liquidation --> deadpoints investments & normal investments
    }

    /* INTERNAL */

    function claimInterests(uint id) internal {
        dTokenData memory dToken = allDTokensData[id];
        uint interestGenerated = (interestPaidPerToken -
            dToken.interestClaimedPerDepositedToken) * dToken.depositedAmount;

        uint defaultToBeClaimed = (defaultedPerToken -
            dToken.defaultedClaimedPerDepositedToken) * dToken.depositedAmount;

        SafeERC20.safeTransfer(
            ERC20(s_pool.principleToken),
            msg.sender,
            interestGenerated
        );

        SafeERC20.safeTransfer(
            ERC20(s_pool.defaultToken),
            msg.sender,
            defaultToBeClaimed
        );

        allDTokensData[id]
            .interestClaimedPerDepositedToken = interestPaidPerToken;
        allDTokensData[id]
            .defaultedClaimedPerDepositedToken = defaultedPerToken;
    }

    /*
    a --> 10000 (100%)
    b --> x
     */
    function threeRule(uint a, uint b) internal pure returns (uint) {
        return (b * 10000) / a;
    }

    /*
      10000 --> a
       b --> x
     */
    function inverseThreeRule(uint a, uint b) internal pure returns (uint) {
        return (a * b) / 10000;
    }

    // ------- VIEW ---------
    function getRealTimeDataBYNFT(
        uint id
    ) public view returns (dTokenInformation memory) {
        dTokenData memory dToken = allDTokensData[id];
        // Calculate active being Lent
        uint porcentageBeingBorrowed = threeRule(
            totalDeposited,
            totalBorrowed - totalPaid
        );
        uint totalBeingLent = inverseThreeRule(
            dToken.depositedAmount,
            porcentageBeingBorrowed
        );

        uint interestGenerated = (interestPaidPerToken -
            dToken.interestClaimedPerDepositedToken) * dToken.depositedAmount;

        return
            dTokenInformation({
                depositedAmount: dToken.depositedAmount,
                activeAmountBeingLent: totalBeingLent,
                expectedInterest: (totalBeingLent * s_pool.interest) / 10000,
                interestGenerated: interestGenerated,
                interestClaimedPerDepositedToken: dToken
                    .interestClaimedPerDepositedToken,
                defaultToBeClaimed: defaultedPerToken -
                    dToken.defaultedClaimedPerDepositedToken,
                defaultedClaimedPerDepositedToken: dToken
                    .defaultedClaimedPerDepositedToken,
                blockDeposit: dToken.blockDeposit,
                Deadpoint: dToken.Deadpoint
            });
    }

    function getDataFeed_Principle() public view returns (int) {
        require(checkSequencer() == true, "Sequencer is down");
        // prettier-ignore
        (, int answer, ,,) = dataFeed_Principle.latestRoundData();
        return answer;
    }

    function getDataFeed_Collateral() public view returns (int) {
        require(checkSequencer() == true, "Sequencer is down");
        (, int answer, , , ) = dataFeed_Collateral.latestRoundData();
        return answer;
    }

    function checkSequencer() public view returns (bool) {
        /* uint answer = 1;
        uint  startedAt = block.timestamp;
*/
        (, int256 answer, uint256 startedAt, , ) = sequencerUptimeFeed
            .latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // Make sure the grace period has passed after the
        // sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }

        return true;
    }
}
/* 

Check interest among lenders 


Total anterior: Cantidad total de tokens depositados en la pool (Sin contar lo que se esta depositando)

Prestado anterior: Cantidad de tokens que estaban siendo prestados de los usuarios anteriores

Nuevo prestado: Cuantos tokens de los usuarios anteriores se estan prestando ahora mismo (despues de ser diluidos)

 
100 ----> Total anterior
Prestado anterior ---> X  (Cuantos tokens estaban siendo prestados de los usuarios anteriores)

100 -----> Nuevo total
Nuevo prestado ----> Y (Cuantos tokens de los usuariores anteriores se estan prestando ahora mismo)

DiluciónDeEntrada = X - Y

InteresPagado = DiluciónDeEntrada / TotalAnterior * Interes

Tokens a transferir penalización = InteresPagado * TotalAnterior



 */
