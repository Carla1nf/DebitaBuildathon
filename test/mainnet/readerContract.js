const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lock", function () {
  it("Deploy", async () => {
    const ownerships = await ethers.getContractFactory("ReaderVeNFT");
    //    const debitaLoanFactoryV2 = await DebitaV2Factory.attach("0xC7b565A1323F03DFea85969eB46d9327a1370c4a");
    const ownershipsContract = await ownerships.deploy();
    /* await debitaLoanFactoryV2.setDebitaOfferFactory(contractOfferFactoryV2.target);
        await contractOfferFactoryV2.setLoanFactoryV2(debitaLoanFactoryV2.target); */
    console.log("ownerships: ", ownershipsContract.target);
  });
});
