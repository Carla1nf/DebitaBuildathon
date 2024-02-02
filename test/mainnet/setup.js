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
    const DebitaOffer = await ethers.getContractFactory("DebitaV2Offers");
    const contractOffer = "0x81c5bbad770E4f77bE4AF0EA421faC7928EA9971";
    const holder = "0x548D484F5d768a497A1919a57f643AEF403FE3BE";
    const holderEQUAL = await ethers.getImpersonatedSigner(holder);

    const offer = await DebitaOffer.attach(contractOffer);
    console.log(valueInWei(0.04));
    const tx = await offer
      .connect(holderEQUAL)
      .acceptOfferAsBorrower(valueInWei(0.04), 8278);
    console.log(tx);

    //  await debitaofferFactory.setLoanFactoryV2(debitaLoanFactoryV2.target);
    //  await ownershipsContract.setDebitaContract(debitaLoanFactoryV2.target);
    //  await debitaLoanFactoryV2.setOwnershipAddress(ownershipsContract.target);

    //  await debitaofferFactory.setVeNFT(veEqualAddress);
    console.log("success");
  });
});
