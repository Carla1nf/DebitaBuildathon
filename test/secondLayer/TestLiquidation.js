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
  const equalAddress = "0x3Fd3A0c85B70754eFc07aC9Ac0cbBDCe664865A6";
  //  before each

  const veEqualAddress = "0x8313f3551C4D3984FfbaDFb42f780D0c8763Ce94";

  let owner;
  let signer1;
  let signerUser2;
  let holderEQUAL;
  let dutchContract;
  let contractVeEqual;
  let veEqualID;
  let auction;

  async function checkPrice(expectedPrice) {
    const currentPrice = await auction.getCurrentPrice();
    const diferencia = currentPrice - expectedPrice;
    console.log(Number(diferencia) / Number(10 ** 18), "diferencia");
    expect(expectedPrice == currentPrice || diferencia < valueInWei(0.0001)).to
      .be.true;
  }

  this.beforeAll(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    signer1 = signers[1];
    signerUser2 = signers[2];
  });

  beforeEach(async function () {
    const dutchFactory = await ethers.getContractFactory(
      "auctionFactoryDebita"
    );
    const erc20 = await ethers.getContractFactory("ERC20DEBITA");

    const accounts = "0x89A7c531178CD6EB01994361eFc0d520a3a702C6";
    holderEQUAL = await ethers.getImpersonatedSigner(accounts);

    const veEqualContract = await ethers.getContractFactory("veEQUAL");
    contractVeEqual = await veEqualContract.attach(veEqualAddress);

    contractERC20 = await erc20.attach(equalAddress);
    await contractERC20
      .connect(holderEQUAL)
      .approve(contractVeEqual.target, valueInWei(10000));

    await contractVeEqual
      .connect(holderEQUAL)
      .create_lock(valueInWei(10), 864000);
    const secondUserSupply = await contractVeEqual.tokensOfOwner(
      holderEQUAL.address
    );
    const secondTokenId = Number(secondUserSupply[secondUserSupply.length - 1]);
    veEqualID = secondTokenId;

    dutchContract = await dutchFactory.deploy();
    await contractVeEqual
      .connect(holderEQUAL)
      .approve(dutchContract.target, veEqualID);

    const tx = await dutchContract
      .connect(holderEQUAL)
      .createAuction(
        veEqualID,
        veEqualAddress,
        equalAddress,
        valueInWei(10),
        valueInWei(2),
        86400 * 10
      );
    const receipt = await tx.wait();
    const auctionAddress = receipt.logs[1].args[0];
    auction = await ethers.getContractAt("dutchAuction_veNFT", auctionAddress);
  }),
    it("Check price decreasing", async function () {
      await checkPrice(valueInWei(10));
      await time.increase(86400);
      await checkPrice(valueInWei(9.2));
      await time.increase(86400 * 8);
      await checkPrice(valueInWei(2.8));
      await time.increase(86400);
      await checkPrice(valueInWei(2));
      await time.increase(86400 * 100);
      await checkPrice(valueInWei(2));
    }),
    it("Check changing price floor", async () => {
      await checkPrice(valueInWei(10));
      await time.increase(86400);
      await auction.connect(holderEQUAL).editFloorPrice(valueInWei(1));
      await checkPrice(valueInWei(9.2));
      await time.increase(86400);
      await checkPrice(valueInWei(8.4));
      await time.increase(86400);
      await checkPrice(valueInWei(7.6));
      await time.increase(86400 * 100);
      await checkPrice(valueInWei(1));

      // Save the real owner, not the pool factory
    }),
    it("Buy the NFT", async () => {
      const buyer = "0x44cA5F5ca91C134b09D28E2b21f5482d4c182Aef";
      const buyerSigner = await ethers.getImpersonatedSigner(buyer);
      const balanceBefore = await contractERC20.balanceOf(holderEQUAL.address);
      await contractERC20
        .connect(buyerSigner)
        .approve(auction.target, valueInWei(10));
      await auction.connect(buyerSigner).buyNFT();

      const ownerNFT = await contractVeEqual.ownerOf(veEqualID);
      const balanceSeller = await contractERC20.balanceOf(holderEQUAL.address);
      expect(ownerNFT).to.be.equal(buyer);
      expect(balanceSeller - balanceBefore).to.be.equal(valueInWei(10));
    });
});
