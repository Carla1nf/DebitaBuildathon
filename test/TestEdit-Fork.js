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
    let contractOffersV2_Secomd;

    let contractLoansV2;
    let contractLoansV2_Second;
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
      const contractOffers = await ethers.getContractFactory("DebitaV2Offers");
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


      
  
    
      const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [1000, 1500],
        [false, false],
        1000,
        [0, 1000],
        100,
        1,
        86400,
        [true, true],
        equalAddress
      );

      const tx2 = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [1000, 2000],
        [false, false],
        1000,
        [0, 0],
        0,
        1,
        86400,
        [false, true],
        equalAddress
      );
      
    for(let i = 0; i < 2; i++) {
      let _tx = i == 0 ? tx : tx2;
      const receipt = await _tx.wait();
      const createdOfferAddress = receipt.logs[1].args[1];

    if(i == 0) {
      contractOffersV2 = await contractOffers.attach(createdOfferAddress);
    } else {
      contractOffersV2_Secomd = await contractOffers.attach(createdOfferAddress);
    }
    
    const address = i == 0 ? contractOffersV2.target : contractOffersV2_Secomd.target;
        
      await contractERC20.connect(signerUser2).approve(address, valueInWei(10000));
      await contractERC20.connect(holderEQUAL).approve(address, valueInWei(10000));

  
     
 
    }
    }),
    it("Edit offer and receive funds as Lender owner", async () => {
      const balanceBefore = await contractERC20.balanceOf(holderEQUAL.address);
      await contractOffersV2.connect(holderEQUAL).editOffer(
       [800, 2000],
       [500, 1, 86400],
       0,
       0
      );
      const offerData = await contractOffersV2.getOffersData();
      const balanceAfter = await contractERC20.balanceOf(holderEQUAL.address);
      checkData(offerData, [0, 1, 4], [[equalAddress, equalAddress], [800, 2000], [0, 1000]])
      expect(balanceAfter - balanceBefore).to.be.equal(200);
    }),

    it("Edit offer and receive funds as Borrow owner", async () => {
        const balanceBefore = await contractERC20.balanceOf(holderEQUAL.address);
        await contractOffersV2_Secomd.connect(holderEQUAL).editOffer(
         [1000, 1800],
         [500, 1, 86400],
         0,
         0
        );
        const offerData = await contractOffersV2_Secomd.getOffersData();
        const balanceAfter = await contractERC20.balanceOf(holderEQUAL.address);
        checkData(offerData, [0, 1, 4], [[equalAddress, equalAddress], [1000, 1800], [0, 0]])
        expect(balanceAfter - balanceBefore).to.be.equal(200);
    })
})