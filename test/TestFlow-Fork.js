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
  let debitaLoanFactoryV2_Contract;
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
    const DebitaV2Factory = await ethers.getContractFactory("DebitaV2LoanFactory");
    const debitaLoanFactoryV2 = await DebitaV2Factory.deploy();
    const erc721 = await ethers.getContractFactory("ABIERC721");
    contractERC721 = await erc721.deploy();
    // Deploy Contracts & Accounts
    contractLoansV2 = await ethers.getContractFactory("DebitaV2Loan");
    const owners = await ethers.getContractFactory("Ownerships");
    ownerships = await owners.deploy();
    const factory = await ethers.getContractFactory("DebitaV2OfferFactory");
    contractFactoryV2 = await factory.deploy();
    await debitaLoanFactoryV2.setDebitaOfferFactory(contractFactoryV2.target);
    const erc20 = await ethers.getContractFactory("ERC20DEBITA");
    contractOffersV2 = await ethers.getContractFactory("DebitaV2Offers");
    contractERC20 = await erc20.attach(equalAddress);
    const accounts = "0x89A7c531178CD6EB01994361eFc0d520a3a702C6";
    holderEQUAL = await ethers.getImpersonatedSigner(accounts);

    // Setup
    await ownerships.setDebitaContract(debitaLoanFactoryV2.target);
    await debitaLoanFactoryV2.connect(owner).setOwnershipAddress(ownerships.target);

    await contractFactoryV2.setLoanFactoryV2(debitaLoanFactoryV2.target);

    await contractERC20.connect(holderEQUAL).approve(contractFactoryV2.target, valueInWei(10000))

    await contractERC20.connect(holderEQUAL).transfer(signerUser2.address, valueInWei(100))

    await contractERC20.connect(signerUser2).approve(contractFactoryV2.target, valueInWei(10000));

    await contractERC20.connect(signerUser2).approve(debitaLoanFactoryV2.target, valueInWei(10000));

     debitaLoanFactoryV2_Contract = debitaLoanFactoryV2; 

  });


  it("Create & Cancel Lending Offer  -- as Lender & Borrower with $EQUAL  (Lending: ERC-20, Collateral: ERC-20)", async () => {
    const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
      [equalAddress, equalAddress],
      [100, 100],
      [false, false],
      10,
      [0,0],
      0,
      1,
      86400,
      [true, false],
      equalAddress
    );

    const tx2 = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
      [equalAddress, equalAddress],
      [100, 100],
      [false, false],
      10,
      [0,0],
      0,
      1,
      86400,
      [false, false],
      equalAddress
    );
    // Get events
    const receipt = await tx.wait()
    const receipt2 = await tx2.wait()
    const createdReceipt = [receipt, receipt2]
    let currentReceipt;
    
    for(let i = 0; i < 2; i++) {
      currentReceipt = createdReceipt[i];
      const createdOfferAddress = currentReceipt.logs[1].args[1];

      //  --- Check if funding got there ---
      expect(await contractFactoryV2.isSenderAnOffer(createdOfferAddress)).to.be.true;
      expect(await contractERC20.balanceOf(createdOfferAddress)).to.be.equal(100);
      // ------
  
      // Cancel and check if value gets back
      const offerContract = await contractOffersV2.attach(createdOfferAddress);
  
      const offerDataBefore = await offerContract.getOffersData();
      checkData(offerDataBefore, [10], [true]);
  
      await offerContract.connect(holderEQUAL).cancelOffer();
  
      expect(await contractERC20.balanceOf(createdOfferAddress)).to.be.equal(0);
      const offerData = await offerContract.getOffersData();
      checkData(offerData, [9], [false])
      await expect(offerContract.connect(holderEQUAL).cancelOffer()).to.be.revertedWith("Offer is not active.");
    }

  }),

    it("Accept Offer, Create loan, Pay it & Claim it -- as Lender & Borrow with $EQUAL (Lending: ERC-20, Collateral: ERC-20)", async () => {

      const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [100, 200],
        [false, false],
        10,
        [0,0],
        0,
        1,
        86400,
        [true,false],
        equalAddress
      );

      const tx2 = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [100, 200],
        [false, false],
        10,
        [0,0],
        0,
        1,
        86400,
        [false, false],
        equalAddress
      );
      // Get events
      const receipt = await tx.wait()
      const receipt2 = await tx2.wait()
      const createdReceipt = [receipt, receipt2]
      let currentReceipt;

      for(let i = 0; i < 2; i++) {

        const borrower = i == 0 ? signerUser2 : holderEQUAL;
        const lender = i == 0 ? holderEQUAL : signerUser2;


        currentReceipt = createdReceipt[i];
        const createdOfferAddress = currentReceipt.logs[1].args[1];
        const offerContract = await contractOffersV2.attach(createdOfferAddress);
  
        await contractERC20.connect(signerUser2).approve(offerContract.target, valueInWei(10000))
  
        /* 
        ACCEPT OFFER 
        */
        let tx_Accept;
        if (i == 0) {
          tx_Accept  = await offerContract.connect(signerUser2).acceptOfferAsBorrower(10, 0);
  
        } else {
          tx_Accept  = await offerContract.connect(signerUser2).acceptOfferAsLender(10, 0);
        }
        const offerData = await offerContract.getOffersData();
        const receipt_accept = await tx_Accept.wait()
  
        const createdLoanAddress = receipt_accept.logs[3].args[1];
        const loanContract = await contractLoansV2.attach(createdLoanAddress);
     
        
        checkData(offerData, [1], [[90, 180]]);
        expect(await contractERC20.balanceOf(createdLoanAddress)).to.be.equal(20);
        if(i == 0) {
          expect(await debitaLoanFactoryV2_Contract.NftID_to_LoanAddress(1)).to.equal(createdLoanAddress);
          expect(await contractERC20.balanceOf(createdOfferAddress)).to.be.equal(90);
          const datauri = await ownerships.tokenURI(2);
          console.log(datauri, "URI");
        } else {
          expect(await contractERC20.balanceOf(createdOfferAddress)).to.be.equal(180);
          expect(await debitaLoanFactoryV2_Contract.NftID_to_LoanAddress(3)).to.equal(createdLoanAddress);

        }
  
        const loanData = await loanContract.getLoanData();
       // checkData(loanData, [0, 2, 4, 5, 6], [i == 0 ? [1, 2] : [3,4], [0, 0, 0], 86400, equalAddress]);

       
        /* 
        REPAY LOAN
        */
        await contractERC20.connect(borrower).approve(loanContract.target, valueInWei(10000))
        await loanContract.connect(borrower).payDebt();
  
        // Check payment back
        const balanceBefore = await contractERC20.balanceOf(borrower.address);
        const addOffer = await loanContract.debitaOfferV2();
        await loanContract.connect(borrower).claimCollateralasBorrower();
        const balanceAfter = await contractERC20.balanceOf(borrower.address);
        expect(balanceAfter - (balanceBefore)).to.be.equal(20);
        
    
        /* 
        CLAIM DEBT AS LENDER
        */
        const balanceBeforeDebt = await contractERC20.balanceOf(lender.address);
        const debt = await loanContract.claimableAmount();
        await loanContract.connect(lender).claimDebt();
        const balanceAfterDebt = await contractERC20.balanceOf(lender.address);
        expect(balanceAfterDebt - (balanceBeforeDebt)).to.be.equal(10);
      }
     
    }),

    it("Create Loan, Default it & Claim it -- as Lender & Borrower with $EQUAL  (Lending: ERC-20, Collateral: ERC-20)", async () => {
      const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [100, 200],
        [false, false],
        10,
        [0,0],
        0,
        1,
        86400,
        [true,false],
        equalAddress
      );

      const tx2 = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
        [equalAddress, equalAddress],
        [100, 200],
        [false, false],
        10,
        [0,0],
        0,
        1,
        86400,
        [false, false],
        equalAddress
      );

      const receipt = await tx.wait();
      const receipt2 = await tx2.wait()
      const createdReceipt = [receipt, receipt2]
      let currentReceipt;

      for(let i = 0; i < 2; i++) {
        const borrower = i == 0 ? signerUser2 : holderEQUAL;
        const lender = i == 0 ? holderEQUAL : signerUser2;
        currentReceipt = createdReceipt[i];

        const createdOfferAddress = currentReceipt.logs[1].args[1];
      const offerContract = await contractOffersV2.attach(createdOfferAddress);

      await contractERC20.connect(borrower).approve(offerContract.target, valueInWei(10000));

      await contractERC20.connect(lender).approve(offerContract.target, valueInWei(10000));
      let tx_Accept;
     if(i == 0) {
      tx_Accept = await offerContract.connect(borrower).acceptOfferAsBorrower(100, 0);
     } else {

      tx_Accept = await offerContract.connect(lender).acceptOfferAsLender(100, 0);
     }

    

      const receipt_accept = await tx_Accept.wait();

      const createdLoanAddress = receipt_accept.logs[3].args[1];
      const loanContract = await contractLoansV2.attach(createdLoanAddress);
      await expect(loanContract.connect(lender).claimCollateralasLender()).to.be.reverted;
      await time.increase(time.duration.days(2));

      // Get balance before and after
      const balanceBefore = await contractERC20.balanceOf(lender.address);
      await loanContract.connect(lender).claimCollateralasLender();
      const balanceAfter = await contractERC20.balanceOf(lender.address);
      expect(balanceAfter - (balanceBefore)).to.be.equal(200);
      }
    })
});
