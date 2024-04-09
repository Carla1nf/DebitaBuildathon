const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

const { ethers } = require("hardhat");

function valueInWei(value) {
  return ethers.parseUnits(`${value}`);
}

describe("Lock", function () {
  it("Deploy", async () => {
    const DebitaOffer = await ethers.getContractFactory("DebitaV2OfferFactory");
    const OwnershipContract = await ethers.getContractFactory("Ownerships");
    const LoanFactoryContract = await ethers.getContractFactory(
      "DebitaV2LoanFactory"
    );

    const offerAddress = "0xAd9D8a2687669550A8779d64e737D4b29753E80D";
    const ownershipAddress = "0x41746483F983E6863Ef266a1267Bb54638407b7F";
    const loanAddress = "0x29012fB2948056DdcB30072dC96Fe293adDa7B3d";
    const veEqualAddress = "0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94";

    const debitaofferFactory = await DebitaOffer.attach(offerAddress);
    const ownershipsContract = await OwnershipContract.attach(ownershipAddress);
    const debitaLoanFactoryV2 = await LoanFactoryContract.attach(loanAddress);

    // await debitaofferFactory.setLoanFactoryV2(debitaLoanFactoryV2.target);
    // await ownershipsContract.setDebitaContract(debitaLoanFactoryV2.target);
    //await debitaLoanFactoryV2.setOwnershipAddress(ownershipsContract.target);
    await debitaLoanFactoryV2.setDebitaOfferFactory(debitaofferFactory.target);
    //  await debitaofferFactory.setVeNFT(veEqualAddress);

    console.log("success");
  });
});
