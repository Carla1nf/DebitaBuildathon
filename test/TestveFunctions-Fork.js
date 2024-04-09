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
    createdReceipt = supplyUser;
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
        [false, false],
        equalAddress
      );

    const receipt = await tx.wait();
    const createdOfferAddress = receipt.logs[1].args[1];
    const contractOffers = await ethers.getContractFactory("DebitaV2Offers");
    contractOffersV2 = await contractOffers.attach(createdOfferAddress);

    await contractERC20
      .connect(holderEQUAL)
      .approve(contractOffersV2.target, valueInWei(10000));

    const tx_Accept = await contractOffersV2
      .connect(holderEQUAL)
      .acceptOfferAsLender(1000, 0);

    const receipt_accept = await tx_Accept.wait();

    const createdLoanAddress = receipt_accept.logs[3].args[1];
    contractLoansV2 = await loanContract.attach(createdLoanAddress);

    await contractFactoryV2.setVeNFT(veEqualAddress);
  }),
    /*  it("Vote with veEqual - using it as collateral", async () => {
      
     await contractLoansV2.connect(holderEQUAL)._voteWithVe(["0x3d6c56f6855b7Cc746fb80848755B0a9c3770122"], [10000]);

        
    }),

    it("Extend Lock of the veEqual - using it as collateral", async () => {
    

        await time.increase(86400 * 30);
        const befores = await contractVeEqual.locked__end(veEqualID);
        await contractLoansV2.connect(holderEQUAL).increaseLock(86400 * 7 * 26);
        const end = await contractVeEqual.locked__end(veEqualID);
    
        expect(end).to.be.above(befores);



    }), */

    it("Collect bribes of the veEqual", async () => {
      const wFTM_Interface = await ethers.getContractFactory("ERC20DEBITA");

      const wftmAddress = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83";
      const wFTM_Contract = await wFTM_Interface.attach(wftmAddress);
      const wFTMHolder = await ethers.getImpersonatedSigner(
        "0x7B7B957c284C2C227C980d6E2F804311947b84d0"
      );
      await contractERC20
        .connect(holderEQUAL)
        .approve(bribeAddress, valueInWei(10000));

      await wFTM_Contract
        .connect(wFTMHolder)
        .approve(bribeAddress, valueInWei(10000));

      await contractERC20
        .connect(holderEQUAL)
        .approve(contractLoansV2.target, valueInWei(10000));
      await contractLoansV2.connect(holderEQUAL).payDebt();

      await contractLoansV2
        .connect(holderEQUAL)
        ._voteWithVe(["0x3d6c56f6855b7Cc746fb80848755B0a9c3770122"], [10000]);

      const interfaceBribe = await ethers.getContractFactory("BribeContract");
      const bribeContract = await interfaceBribe.attach(bribeAddress);

      await bribeContract
        .connect(holderEQUAL)
        .notifyRewardAmount(equalAddress, valueInWei(10));

      await bribeContract
        .connect(wFTMHolder)
        .notifyRewardAmount(wftmAddress, valueInWei(1000));

      await time.increase(86400 * 30);

      const beforeClaiming = await contractERC20.balanceOf(holderEQUAL.address);

      const beforeClaiming_wFTM = await contractERC20.balanceOf(
        holderEQUAL.address
      );

      await contractLoansV2
        .connect(holderEQUAL)
        .claimBribes([bribeAddress], [[equalAddress, wftmAddress]]);

      const afterClaiming = await contractERC20.balanceOf(holderEQUAL.address);
      const afterClaiming_wFTM = await contractERC20.balanceOf(
        holderEQUAL.address
      );

      const balanceAddressBefore = await contractERC20.balanceOf(
        holderEQUAL.address
      );
      await contractLoansV2.connect(holderEQUAL).claimDebt();
      await contractLoansV2.connect(holderEQUAL).claimCollateralasBorrower();
      const supplyUser = await contractVeEqual.tokensOfOwner(
        holderEQUAL.address
      );
      console.log(veEqualID, supplyUser);
      const balanceAddressAfter = await contractERC20.balanceOf(
        holderEQUAL.address
      );
      const data = await contractLoansV2.getLoanData();
      console.log(data);

      //  expect(afterClaiming).to.be.above(beforeClaiming);
      //  expect(afterClaiming_wFTM).to.be.above(beforeClaiming_wFTM);
      /*    expect(Number(balanceAddressAfter - balanceAddressBefore)).to.be.equal(
        1088
      ); */
    }),
    it("Use veFunctions & default", async () => {
      it("Collect bribes of the veEqual", async () => {
        const wFTM_Interface = await ethers.getContractFactory("ERC20DEBITA");

        const wftmAddress = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83";
        const wFTM_Contract = await wFTM_Interface.attach(wftmAddress);
        const wFTMHolder = await ethers.getImpersonatedSigner(
          "0x7B7B957c284C2C227C980d6E2F804311947b84d0"
        );
        await contractERC20
          .connect(holderEQUAL)
          .approve(bribeAddress, valueInWei(10000));

        await wFTM_Contract
          .connect(wFTMHolder)
          .approve(bribeAddress, valueInWei(10000));

        await contractERC20
          .connect(holderEQUAL)
          .approve(contractLoansV2.target, valueInWei(10000));

        await contractLoansV2
          .connect(holderEQUAL)
          ._voteWithVe(["0x3d6c56f6855b7Cc746fb80848755B0a9c3770122"], [10000]);

        const interfaceBribe = await ethers.getContractFactory("BribeContract");
        const bribeContract = await interfaceBribe.attach(bribeAddress);

        await bribeContract
          .connect(holderEQUAL)
          .notifyRewardAmount(equalAddress, valueInWei(10));

        await bribeContract
          .connect(wFTMHolder)
          .notifyRewardAmount(wftmAddress, valueInWei(1000));

        const beforeClaiming = await contractERC20.balanceOf(
          holderEQUAL.address
        );

        const beforeClaiming_wFTM = await contractERC20.balanceOf(
          holderEQUAL.address
        );

        await contractLoansV2
          .connect(holderEQUAL)
          .claimBribes([bribeAddress], [[equalAddress, wftmAddress]]);

        const afterClaiming = await contractERC20.balanceOf(
          holderEQUAL.address
        );
        const afterClaiming_wFTM = await contractERC20.balanceOf(
          holderEQUAL.address
        );

        const balanceAddressBefore = await contractERC20.balanceOf(
          holderEQUAL.address
        );
        await expect(
          contractLoansV2.connect(holderEQUAL).claimCollateralasLender()
        ).to.be.rejected;
        await time.increase(86400 * 60);
        await expect(
          contractLoansV2.connect(holderEQUAL).claimCollateralasBorrower()
        ).to.be.rejected;
        await contractLoansV2.connect(holderEQUAL).claimCollateralasLender();
        const supplyUser = await contractVeEqual.tokensOfOwner(
          holderEQUAL.address
        );
        console.log(veEqualID, supplyUser);
        const balanceAddressAfter = await contractERC20.balanceOf(
          holderEQUAL.address
        );
        const data = await contractLoansV2.getLoanData();
        console.log(data);

        //  expect(afterClaiming).to.be.above(beforeClaiming);
        //  expect(afterClaiming_wFTM).to.be.above(beforeClaiming_wFTM);
        /*    expect(Number(balanceAddressAfter - balanceAddressBefore)).to.be.equal(
          1088
        ); */
      });
    });
});
