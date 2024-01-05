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

         const debitaLoanFactoryV2 = await DebitaV2LoanFactory.attach("0xeb9Af0989C00b47a4Fb1A6AA56F15d47e379EE6f");
         const debitaofferFactory = await DebitaV2OfferFactory.attach("0x802649C66A6cFA723aE09dfd7889d9bd56D8D0d2");
         const ownershipsContract = await ownerships.attach("0xc242C161b755FD10E408f53477308E184E0A7584");


        await debitaLoanFactoryV2.setOwnershipAddress(ownershipsContract.target);
        await debitaofferFactory.setVeNFT(veEqualAddress);
        console.log("success")

    })
  });