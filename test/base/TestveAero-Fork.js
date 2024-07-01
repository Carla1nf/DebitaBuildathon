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
  const equalAddress = "0x940181a94A35A4569E4529A3CDfB74e38FD98631";
  //  before each

  const veEqualAddress = "0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4";

  let owner;
  let signer1;
  let signerUser2;
  let holderEQUAL;
  let contractFactoryV2;
  let contractOffersV2;
  let contractLoansV2;
  let contractERC20;
  let ownerships;
  let contractERC721;
  let createdReceipt;
  let contractVeEqual;
  let veEqualID;
  let veEqualID_smallAmount;

  function checkData(receipt, indexs, values) {
    for (let i = 0; i < indexs.length; i++) {
      if (typeof receipt[indexs[i]] == "object") {
        expect(receipt[indexs[i]][0]).to.be.equal(values[i][0]);
        expect(receipt[indexs[i]][1]).to.be.equal(values[i][1]);
      } else {
        expect(receipt[indexs[i]]).to.be.equal(values[i]);
      }
    }
  }

  this.beforeAll(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    signer1 = signers[1];
    signerUser2 = signers[2];
    const accounts = "0x5C235931376b21341fA00d8A606e498e1059eCc0";
    holderEQUAL = await ethers.getImpersonatedSigner(accounts);
    await owner.sendTransaction({
      to: accounts,
      value: ethers.parseEther("10.0"), // Sends exactly 1.0 ether
    });
  });

  it("create Lock", async function () {
    const OfferFactory = await ethers.getContractFactory(
      "DebitaV2OfferFactory"
    );
    const veAeroABI = await ethers.getContractFactory("veEQUAL");
    const veAeroContract = await veAeroABI.attach(veEqualAddress);
    const factoryContract = await OfferFactory.deploy();
    await factoryContract.setVeNFT(veEqualAddress);
    await veAeroContract
      .connect(holderEQUAL)
      .approve(factoryContract.target, 20432);
    const tx = await factoryContract
      .connect(holderEQUAL)
      .createOfferV2(
        [
          "0x940181a94A35A4569E4529A3CDfB74e38FD98631",
          "0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4",
        ],
        [1000, 1],
        [false, true],
        200,
        [20432, 0],
        0,
        1,
        86400 * 30,
        [false, true],
        "0x940181a94A35A4569E4529A3CDfB74e38FD98631"
      );
    const receipt = await tx.wait();
    const createdOfferAddress = receipt.logs[1].args[1];
    console.error(createdOfferAddress);
    const contractOffers = await ethers.getContractFactory("DebitaV2Offers");
    const offerContract = await contractOffers.attach(createdOfferAddress);
    const AeroABI = await ethers.getContractFactory("ERC20DEBITA");
    const AeroContract = await AeroABI.attach(
      "0x940181a94A35A4569E4529A3CDfB74e38FD98631"
    );
    await AeroContract.connect(holderEQUAL).approve(createdOfferAddress, 1000);

    const tx2 = await offerContract
      .connect(holderEQUAL)
      .acceptOfferAsLender(1000, 0);

    /*const receipt2 = await tx2.wait();
    const loanAddress = receipt2.logs[1].args[1];
    const loanContract = await ethers.getContractAt(
      "DebitaV2Loan",
      loanAddress
    );
    console.log(loanAddress) */
    //await loanContract.connect(holderEQUAL).claimCollateralasLender();
    // 17385
  });
});
