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
    const equalAddress = "0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6";

    const offerFactory = await ethers.getContractFactory(
      "DebitaV2OfferFactory"
    );
    const debitaOfferFactoryV2 = await offerFactory.attach(
      "0xDa2aa575cB94Ab6e3Bb98C547f9090F3515862f3"
    );

    // await wFTM_Contract.approve(debitaOfferFactoryV2.target, valueInWei(0.4));

    const tx = await debitaOfferFactoryV2.createOfferV2(
      [equalAddress, "0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94"],
      [valueInWei(0.4), 1],
      [false, true],
      1000,
      [0, 10000],
      valueInWei(0.8),
      1,
      86400,
      [true, true],
      equalAddress,
      {
        gasLimit: 6000000,
        from: "0xf23afed29aaf2e2e9690b7fc37b9077e74909eff",
      }
    );
    const receipt = await tx.wait();
    console.log("createdOfferAddress: ", receipt);
  });
});
