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
    const DebitaV = await ethers.getContractFactory("DebitaV2Loan");
    const ownerships = await ethers.getContractFactory("Ownerships");

    const ownerContract = await ownerships.attach(
      "0x7a310d9Bbb62997E2B098E8947E88Bf80b42B103"
    );

    const debita = await DebitaV.deploy(
      [1, 1],
      [ZERO_ADDRESS, ZERO_ADDRESS],
      [1, 1],
      [false, false],
      1,
      [1, 1, 1],
      1,
      1,
      ZERO_ADDRESS,
      [ZERO_ADDRESS, ZERO_ADDRESS],
      ZERO_ADDRESS
    );
    const debitaMainnet = await debita.attach(
      "0x9239e462AD3eA0b05C3b009B44068ad45c2d9c09"
    );

    const holder = "0xd93BAb51CD83881cE1228650B9798EE8FC3E746c";

    const holderEQUAL = await ethers.getImpersonatedSigner(holder);
    await debitaMainnet
      .connect(holderEQUAL)
      .claimCollateralasBorrower({ gasLimit: 900000 });
  });
});
