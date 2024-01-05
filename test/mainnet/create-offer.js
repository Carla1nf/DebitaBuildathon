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
   it("Create Offer", async () => {
    const wFTM_Interface = await ethers.getContractFactory("ERC20DEBITA");
    const equalAddress = "0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6";
    const wftmAddress = "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83";
    const wFTM_Contract = await wFTM_Interface.attach(wftmAddress);
   // await wFTM_Contract.approve("0x40afe7298c1b31796dc410cdadb3132ff3004d57", valueInWei(100));
    const offerFactory = await ethers.getContractFactory("DebitaV2OfferFactory"); 
    const debitaOfferFactoryV2 = await offerFactory.attach("0x40afe7298c1b31796dc410cdadb3132ff3004d57");
    const tx = await debitaOfferFactoryV2.createOfferV2(
        [wFTM_Contract.target, equalAddress],
        [valueInWei(1), valueInWei(0.1)],
        [false, false],
        1000,
        [0, 1000],
        100,
        1,
        86400,
        [true, true],
        equalAddress
      );
      const receipt = await tx.wait();
      console.log("createdOfferAddress: ", receipt); 

   })
 
  })