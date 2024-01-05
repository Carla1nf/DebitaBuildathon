const {
    time,
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
  const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
  const { expect } = require("chai");
  const { ethers } = require("hardhat");

  describe("Lock", function () {
    it("Deploy", async () => {
        const ownerships = await ethers.getContractFactory("Ownerships"); 
        const DebitaV2LoanFactory = await ethers.getContractFactory("DebitaV2LoanFactory");
        const DebitaV2OfferFactory = await ethers.getContractFactory("DebitaV2OfferFactory");
        const veEqualAddress = "0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94";

         const debitaLoanFactoryV2 = await DebitaV2LoanFactory.attach("0x7A170aCb2Bdbf37654dC6Dcce474Ea5e1743C11d");
         const debitaofferFactory = await DebitaV2OfferFactory.attach("0x40afe7298c1b31796dc410cdadb3132ff3004d57");
         const ownershipsContract = await ownerships.attach("0x281aea12908c82B9961E1186F8AAeE2E2c27B10d");

       await debitaLoanFactoryV2.setDebitaOfferFactory(debitaofferFactory.target);
     //  await debitaofferFactory.setLoanFactoryV2(debitaLoanFactoryV2.target);  
     //  await ownershipsContract.setDebitaContract(debitaLoanFactoryV2.target);
   //  await debitaLoanFactoryV2.setOwnershipAddress(ownershipsContract.target);

     //  await debitaofferFactory.setVeNFT(veEqualAddress); 
        console.log("success")

    })
  });