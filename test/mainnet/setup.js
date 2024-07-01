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

    const offerAddress = "0xBA7F80cC18136a8E777348dC047Ef7c167bf4194"; // d
    const ownershipAddress = "0xCd1A78889eCE0992d0b109cF84c2A7f7D09D3B67"; // d
    const loanAddress = "0x56f93b17b32dD0f36aE8A21C235B2d361B35F755"; // d
    const veAeroAddress = "0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4";

    const debitaofferFactory = await DebitaOffer.attach(offerAddress);
    const ownershipsContract = await OwnershipContract.attach(ownershipAddress);
    const debitaLoanFactoryV2 = await LoanFactoryContract.attach(loanAddress);

    //await debitaofferFactory.setLoanFactoryV2(debitaLoanFactoryV2.target);
    //await ownershipsContract.setDebitaContract(debitaLoanFactoryV2.target);
    //await debitaLoanFactoryV2.setOwnershipAddress(ownershipsContract.target);
    //await debitaLoanFactoryV2.setDebitaOfferFactory(debitaofferFactory.target);
    await debitaofferFactory.setVeNFT(veAeroAddress);

    console.log("success");
  });
});
