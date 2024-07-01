const TOKENS_MINTED = "1000000000000000000000";
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const Timelap_10_TIMES = 86400000;
const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { ethers } = require("hardhat");

describe("Debita V1", () => {
  it("Deploy Contract", async () => {
    const signers = await ethers.getSigners();
    const owner = signers[0];
    const DebitaV = await ethers.getContractFactory("DebitaV2OfferFactory");

    const ownerContract = await DebitaV.attach(
      "0xBA7F80cC18136a8E777348dC047Ef7c167bf4194"
    );

    const data = await ownerContract.isContractVeNFT(
      "0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4"
    );

    console.log(data);
  });
});
