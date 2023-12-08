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

    const veEqualAddress = "0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94"
  
  
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
      const DebitaV2Factory = await ethers.getContractFactory("DebitaV2LoanFactory");
      const debitaLoanFactoryV2 = await DebitaV2Factory.deploy();
      const erc721 = await ethers.getContractFactory("ABIERC721");
      contractERC721 = await erc721.deploy();
      // Deploy Contracts & Accounts
      const loanContract = await ethers.getContractFactory("DebitaV2Loan");
      const owners = await ethers.getContractFactory("Ownerships");
      ownerships = await owners.deploy();
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
      await ownerships.setDebitaContract(debitaLoanFactoryV2.target);

      await debitaLoanFactoryV2.connect(owner).setOwnershipAddress(ownerships.target);

      await contractERC20.connect(holderEQUAL).approve(contractFactoryV2.target, valueInWei(10000))
  
      await contractERC20.connect(holderEQUAL).transfer(signerUser2.address, valueInWei(100))
  
      await contractERC20.connect(signerUser2).approve(contractFactoryV2.target, valueInWei(10000));

      await contractERC20.connect(signerUser2).approve(debitaLoanFactoryV2.target, valueInWei(10000));
      
      const veEqualContract = await ethers.getContractFactory("veEQUAL");
      contractVeEqual = await veEqualContract.attach(veEqualAddress);


    }),

    it("Check veEQUAL value", async function () {
      const data = await contractVeEqual.balanceOfNFT(1);
      expect(data > 0).to.be.true;
    }),

    it("create Lock", async function () {
     await contractERC20.connect(holderEQUAL).approve(contractVeEqual.target, valueInWei(10000)); 

     await contractVeEqual.connect(holderEQUAL).create_lock(100, 864000);
     const supplyUser = await contractVeEqual.tokensOfOwner(holderEQUAL.address);
     const tokenId = Number(supplyUser[supplyUser.length - 1])
     veEqualID_smallAmount = tokenId;
     const lockedAmount = await contractVeEqual.locked(tokenId);
     expect(lockedAmount[0]).to.be.equal(100);

     await contractVeEqual.connect(holderEQUAL).create_lock(valueInWei(100), 864000);
     const secondUserSupply = await contractVeEqual.tokensOfOwner(holderEQUAL.address);
     const secondTokenId = Number(secondUserSupply[secondUserSupply.length - 1]);
     veEqualID = secondTokenId;
     const votingPower = await contractVeEqual.balanceOfNFT(secondTokenId);
     console.log(votingPower);
    }),
    it("Create offer, and put lock as collateral", async function () {


     await contractFactoryV2.setVeNFT(veEqualAddress);

     const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
      [veEqualAddress, equalAddress],
      [1, 1500],
      [true, false],
      1000,
      [0, 10000],
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

    await contractVeEqual.connect(holderEQUAL).approve(contractOffersV2.target, veEqualID);

    await contractOffersV2.connect(holderEQUAL).acceptOfferAsLender(1, veEqualID); 

    }),

    it("Create offer, and try to put lock as collateral with low amount", async function () {
      await contractFactoryV2.setVeNFT(veEqualAddress);

      const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
       [veEqualAddress, equalAddress],
       [1, 1500],
       [true, false],
       1000,
       [0, 10000],
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
 
     await contractVeEqual.connect(holderEQUAL).approve(contractOffersV2.target, veEqualID_smallAmount);
      // locked amount of veEqualID_smallAmount == 100, but we need 1000
     await expect(contractOffersV2.connect(holderEQUAL).acceptOfferAsLender(1, veEqualID_smallAmount)).to.be.reverted;
    }),

    it("Accept offer as borrower", async function () {
      await contractFactoryV2.setVeNFT(veEqualAddress);

      const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, veEqualAddress],
        [1000, 1],
        [false, true],
        1000,
        [0, 10000],
        1000,
        1,
        86400,
        [true, true],
        equalAddress
      );

      const tx2 = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, veEqualAddress],
        [1000, 1],
        [false, true],
        1000,
        [0, 10000],
        100,
        1,
        86400,
        [true, true],
        equalAddress
      );
      
      const allTxs = [tx, tx2];
      for(let i = 0; i < 2; i++) {
        let _tx = allTxs[i];
        const receipt = await _tx.wait();
        const createdOfferAddress = receipt.logs[1].args[1];
        const contractOffers = await ethers.getContractFactory("DebitaV2Offers");
        contractOffersV2 = await contractOffers.attach(createdOfferAddress);

        await contractVeEqual.connect(holderEQUAL).approve(contractOffersV2.target, veEqualID_smallAmount);
       if(i == 1) {
        await contractOffersV2.connect(holderEQUAL).acceptOfferAsBorrower(1000, veEqualID_smallAmount);
       } else {
        await expect(contractOffersV2.connect(holderEQUAL).acceptOfferAsBorrower(1000, veEqualID_smallAmount)).to.be.revertedWith("Must be greater than veNFT value");
       }
    }
  
  })
    
});