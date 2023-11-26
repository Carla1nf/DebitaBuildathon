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
  
  describe("Lock", function () {
    const equalAddress = "0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6";
    //  before each
  
  
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
  
    function checkData(receipt, indexs, values) {
      for (let i = 0; i < indexs.length; i++) {
        if ((typeof receipt[indexs[i]]) == "object") {
          expect(receipt[indexs[i]][0]).to.be.equal(values[i][0]);
          expect(receipt[indexs[i]][1]).to.be.equal(values[i][1]);
        } else {
          expect(receipt[indexs[i]]).to.be.equal(values[i]);
        }
      }
    }
  
    this.beforeAll(async () => {
      const signers = await ethers.getSigners();
      owner = signers[0];
      signer1 = signers[1];
      signerUser2 = signers[2];
    });


    beforeEach(async function () {
      const erc721 = await ethers.getContractFactory("ABIERC721");
      contractERC721 = await erc721.deploy();
      // Deploy Contracts & Accounts
      const loanContract = await ethers.getContractFactory("DebitaV2Loan");
      const owners = await ethers.getContractFactory("Ownerships");
      ownerships = await owners.deploy();
      const factory = await ethers.getContractFactory("DebitaV2Factory");
      contractFactoryV2 = await factory.deploy();
      const erc20 = await ethers.getContractFactory("ERC20DEBITA");
      const contractOffers = await ethers.getContractFactory("DebitaV2Offers");
      contractERC20 = await erc20.attach(equalAddress);
      const accounts = "0x89A7c531178CD6EB01994361eFc0d520a3a702C6";
      holderEQUAL = await ethers.getImpersonatedSigner(accounts);
  
      // Setup
      await ownerships.setDebitaContract(contractFactoryV2.target);
      await contractFactoryV2.connect(owner).setOwnershipAddress(ownerships.target);
      await contractERC20.connect(holderEQUAL).approve(contractFactoryV2.target, valueInWei(10000))
  
      await contractERC20.connect(holderEQUAL).transfer(signerUser2.address, valueInWei(100))
  
      await contractERC20.connect(signerUser2).approve(contractFactoryV2.target, valueInWei(10000))
      
  
      const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [1000, 1000],
        [false, false],
        10,
        [0, 0, 0],
        1,
        86400,
        true,
        equalAddress,
        true
      );

      const receipt = await tx.wait();
      const createdOfferAddress = receipt.logs[1].args[1];
      contractOffersV2 = await contractOffers.attach(createdOfferAddress);

        
      await contractERC20.connect(signerUser2).approve(contractOffersV2.target, valueInWei(10000));

      const tx_Accept  = await offerContract.connect(signerUser2).acceptOfferAsBorrower(10, 0);

      const receipt_accept = await tx_Accept.wait();

      const createdLoanAddress = receipt_accept.logs[3].args[1];
      contractLoansV2 = await loanContract.attach(createdLoanAddress);
  
    })

    it("Pay loan and accept it again", async () => {
        await contractERC20.connect(signerUser2).approve(contractLoansV2.target, valueInWei(10000));
        await contractLoansV2.connect(signerUser2).payDebt();
    })
});