const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

function valueInWei(value) {
  return ethers.parseUnits(`${value}`);
}

describe("Debita V2 veEqual collateral functions testing", function () {
  const equalAddress = "0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6";
  //  before each

  const veEqualAddress = "0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94";

  const gaugeAddress = "0x863730009c8e1A460E244cE8CF71f56783F517c3";

  const bribeAddress = "0xFb8Da62305d8C357a67293D571a51fE4854F7f8d";

  let owner;
  let signer1;
  let signerUser2;
  let holderEQUAL;
  let contractFactoryV2;
  let contractOffersV2;
  let contractLoansV2;
  let contractERC20;
  let ownerships;
  let contractERC721;
  let createdReceipt;
  let contractVeEqual;
  let veEqualID;
  let veEqualID_smallAmount;

  function checkData(receipt, indexs, values) {
    for (let i = 0; i < indexs.length; i++) {
      if (typeof receipt[indexs[i]] == "object") {
        expect(receipt[indexs[i]][0]).to.be.equal(values[i][0]);
        expect(receipt[indexs[i]][1]).to.be.equal(values[i][1]);
      } else {
        expect(receipt[indexs[i]]).to.be.equal(values[i]);
      }
    }
  }

  this.beforeAll(async () => {
    const signers = await ethers.getSigners();
    owner = signers[5];
    signer1 = signers[1];
    signerUser2 = signers[2];
  });

  beforeEach(async function () {
    ethers.provider.getBalance;
    const DebitaV2Factory = await ethers.getContractFactory(
      "DebitaV2LoanFactory"
    );
    const debitaLoanFactoryV2 = await DebitaV2Factory.connect(owner).deploy();
    const erc721 = await ethers.getContractFactory("ABIERC721");
    contractERC721 = await erc721.connect(owner).deploy();
    // Deploy Contracts & Accounts
    const loanContract = await ethers.getContractFactory("DebitaV2Loan");
    const owners = await ethers.getContractFactory("Ownerships");
    ownerships = await owners.connect(owner).deploy();
    const factory = await ethers.getContractFactory("DebitaV2OfferFactory");

    contractFactoryV2 = await factory.deploy();
    // Connect both factories
    await debitaLoanFactoryV2.setDebitaOfferFactory(contractFactoryV2.target);

    await contractFactoryV2.setLoanFactoryV2(debitaLoanFactoryV2.target);

    const erc20 = await ethers.getContractFactory("ERC20DEBITA");

    contractERC20 = await erc20.attach(equalAddress);
    const accounts = "0x89A7c531178CD6EB01994361eFc0d520a3a702C6";
    holderEQUAL = await ethers.getImpersonatedSigner(accounts);

    // Setup --> Debita Loan Factory and Ownership contract -- Connected
    await ownerships
      .connect(owner)
      .setDebitaContract(debitaLoanFactoryV2.target);

    await debitaLoanFactoryV2
      .connect(owner)
      .setOwnershipAddress(ownerships.target);

    await contractERC20
      .connect(holderEQUAL)
      .approve(contractFactoryV2.target, valueInWei(10000));

    await contractERC20
      .connect(holderEQUAL)
      .transfer(signerUser2.address, valueInWei(100));

    await contractERC20
      .connect(signerUser2)
      .approve(contractFactoryV2.target, valueInWei(10000));

    await contractERC20
      .connect(signerUser2)
      .approve(debitaLoanFactoryV2.target, valueInWei(10000));

    const veEqualContract = await ethers.getContractFactory("veEQUAL");
    contractVeEqual = await veEqualContract.attach(veEqualAddress);

    await contractERC20
      .connect(holderEQUAL)
      .approve(contractVeEqual.target, valueInWei(10000));

    await contractVeEqual
      .connect(holderEQUAL)
      .create_lock(valueInWei(100), 86400 * 7 * 26);

    const supplyUser = await contractVeEqual.tokensOfOwner(holderEQUAL.address);
    veEqualID = Number(supplyUser[supplyUser.length - 1]);
    await contractVeEqual
      .connect(holderEQUAL)
      .approve(contractFactoryV2.target, veEqualID);

    const tx = await contractFactoryV2
      .connect(holderEQUAL)
      .createOfferV2(
        [equalAddress, veEqualAddress],
        [1000, 1],
        [false, true],
        1000,
        [veEqualID, 10000],
        1000,
        1,
        86400,
        [false, true],
        equalAddress
      );

    const receipt = await tx.wait();
    const createdOfferAddress = receipt.logs[1].args[1];
    const contractOffers = await ethers.getContractFactory("DebitaV2Offers");
    contractOffersV2 = await contractOffers.attach(createdOfferAddress);

    await contractERC20
      .connect(signerUser2)
      .approve(contractOffersV2.target, valueInWei(10000));

    await contractERC20
      .connect(holderEQUAL)
      .transfer(signerUser2.address, valueInWei(100));

    const tx_Accept = await contractOffersV2
      .connect(signerUser2)
      .acceptOfferAsLender(1000, 0);

    const receipt_accept = await tx_Accept.wait();

    const createdLoanAddress = receipt_accept.logs[3].args[1];
    contractLoansV2 = await loanContract.attach(createdLoanAddress);

    await contractFactoryV2.setVeNFT(veEqualAddress);

    await contractERC20
      .connect(holderEQUAL)
      .approve(contractLoansV2.target, valueInWei(10000));
  }),
    it("Vote with veEqual and claim it - using it as collateral", async () => {
      await contractLoansV2
        .connect(holderEQUAL)
        ._voteWithVe(["0x3d6c56f6855b7Cc746fb80848755B0a9c3770122"], [10000]);

      await contractLoansV2.connect(holderEQUAL).payDebt();

      await time.increase(86400 * 7);

      await contractLoansV2.connect(holderEQUAL).claimCollateralasBorrower();

      // No longer Active
      await expect(
        contractLoansV2.connect(holderEQUAL).claimCollateralasBorrower()
      ).to.be.rejected;

      await expect(contractLoansV2.connect(holderEQUAL).payDebt()).to.be
        .rejected;

      await expect(
        contractLoansV2
          .connect(holderEQUAL)
          ._voteWithVe(["0x3d6c56f6855b7Cc746fb80848755B0a9c3770122"], [10000])
      ).to.be.rejected;

      await expect(
        contractLoansV2.connect(holderEQUAL).increaseLock(86400 * 7 * 26)
      ).to.be.rejected;
    }),
    it("Check data after of offer claiming collateral", async () => {
      await expect(
        contractLoansV2.connect(signerUser2).claimCollateralasBorrower()
      ).to.be.rejected;

      await expect(
        contractLoansV2.connect(holderEQUAL).claimCollateralasBorrower()
      ).to.be.rejected;

      await contractLoansV2.connect(holderEQUAL).payDebt();

      await expect(
        contractLoansV2.connect(signerUser2).claimCollateralasBorrower()
      ).to.be.rejected;

      await expect(contractLoansV2.connect(owner).claimCollateralasBorrower())
        .to.be.rejected;

      const data_Before = await contractOffersV2
        .connect(signerUser2)
        .getOffersData();

      checkData(data_Before, [1, 5], [[0, 0], 1000]);

      await contractLoansV2.connect(holderEQUAL).claimCollateralasBorrower();

      const data = await contractOffersV2.connect(signerUser2).getOffersData();

      checkData(data, [1, 5], [[1000, 1], 1000]);
    });
  it("Test offer", async () => {
    await expect(
      contractOffersV2.connect(holderEQUAL).acceptOfferAsLender(1000, 0)
    ).to.be.rejected;

    await expect(
      contractOffersV2.connect(holderEQUAL).acceptOfferAsBorrower(1000, 0)
    ).to.be.rejected;

    await expect(contractOffersV2.connect(signerUser2).insertAssets(1000)).to.be
      .rejected;

    await expect(
      contractOffersV2
        .connect(holderEQUAL)
        .editOffer([100, 100], [0, 3, 86400], 1000, 100)
    ).to.be.rejected;
  });
});
