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
  let buyer;
  let signerUser2;
  let holderEQUAL;
  let dutchContract;
  let contractVeEqual;
  let veEqualID;
  let auction;

  async function checkPrice(expectedPrice) {
    const currentPrice = await auction.getCurrentPrice();
    const diferencia = currentPrice - expectedPrice;
    console.log("Current Price: ", currentPrice.toString());
    expect(
      expectedPrice == currentPrice ||
        (diferencia < valueInWei(0.0001) && diferencia > valueInWei(-0.0001))
    ).to.be.true;
  }

  this.beforeAll(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    buyer = signers[1];
    signerUser2 = signers[2];
    const erc20 = await ethers.getContractFactory("ERC20DEBITA");
    const veEqualContract = await ethers.getContractFactory("ABIERC721");
    contractVeEqual = await veEqualContract.deploy();

    contractERC20 = await erc20.deploy();
  });

  beforeEach(async function () {
    const dutchFactory = await ethers.getContractFactory(
      "auctionFactoryDebita"
    );

    const txMint = await contractVeEqual.connect(owner).mint();
    const mintReceipt = await txMint.wait();
    const id = mintReceipt.logs[0].args[2];
    veEqualID = id;

    dutchContract = await dutchFactory.deploy();
    await contractVeEqual
      .connect(owner)
      .approve(dutchContract.target, veEqualID);

    const tx = await dutchContract
      .connect(owner)
      .createAuction(
        veEqualID,
        contractVeEqual.target,
        contractERC20.target,
        valueInWei(10),
        valueInWei(2),
        86400 * 10
      );
    const receipt = await tx.wait();
    const auctionAddress = receipt.logs[1].args[0];
    auction = await ethers.getContractAt("dutchAuction_veNFT", auctionAddress);
    await contractERC20.connect(buyer).mint(valueInWei(100));
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
      await auction.connect(owner).editFloorPrice(valueInWei(1));
      await checkPrice(valueInWei(9.2));
      await time.increase(86400);
      await checkPrice(valueInWei(8.4));
      console.log(signerUser2.address);
      await time.increase(86400);
      await checkPrice(valueInWei(7.6));
      await time.increase(86400 * 100);
      await checkPrice(valueInWei(1));
      // edit it again --
      await auction.connect(owner).editFloorPrice(valueInWei(0.1));
      await checkPrice(valueInWei(1));
      await time.increase(86400);
      await checkPrice(valueInWei(0.2));
      await time.increase(86400);
      await checkPrice(valueInWei(0.1));
      await expect(auction.connect(owner).editFloorPrice(valueInWei(0.1))).to.be
        .rejected;
      await expect(auction.connect(owner).editFloorPrice(valueInWei(1))).to.be
        .rejected;
      await expect(
        auction.connect(signerUser2).editFloorPrice(valueInWei(0.01))
      ).to.be.rejected;

      // Save the real owner, not the pool factory
    });
  it("Buy the NFT", async () => {
    const balanceBefore = await contractERC20.balanceOf(owner.address);
    await contractERC20.connect(buyer).approve(auction.target, valueInWei(100));

    // Try to buy from a wallet without balance
    await expect(auction.connect(signerUser2).buyNFT()).to.be.rejected;
    // Buy the NFT
    await auction.connect(buyer).buyNFT();
    const ownerNFT = await contractVeEqual.ownerOf(veEqualID);
    const balanceSeller = await contractERC20.balanceOf(owner.address);
    // Try to buy it again after sold
    await expect(auction.connect(buyer).buyNFT()).to.be.rejected;

    expect(ownerNFT).to.be.equal(buyer.address);
    expect(balanceBefore).to.be.equal(0);
    expect(balanceSeller > valueInWei(9.999) && balanceSeller < valueInWei(10))
      .to.be.true;
  }),
    it("Cancel offer", async () => {
      await auction.connect(owner).cancelOffer();
      await contractERC20
        .connect(buyer)
        .approve(auction.target, valueInWei(100));
      const ownerNFT = await contractVeEqual.ownerOf(veEqualID);
      const data = await auction.s_CurrentAuction();
      expect(data[7]).to.be.false;
      await expect(auction.connect(buyer).buyNFT()).to.be.rejected;
      await expect(auction.connect(owner).cancelOffer()).to.be.rejected;
      expect(ownerNFT).to.be.equal(owner.address);
    }),
    it("Check Rejects", async () => {
      await expect(auction.connect(signerUser2).editFloorPrice(valueInWei(1)))
        .to.be.rejected;
      await expect(auction.connect(signerUser2).cancelOffer()).to.be.rejected;
      await expect(auction.connect(signerUser2).buyNFT()).to.be.rejected;
    }),
    it("Price floor liquidation", async () => {
      const txMint = await contractVeEqual.connect(signerUser2).mint();
      const mintReceipt = await txMint.wait();
      const id = mintReceipt.logs[0].args[2];
      veEqualID = id;

      await contractVeEqual
        .connect(signerUser2)
        .approve(dutchContract.target, veEqualID);
      await dutchContract.connect(owner).setPoolFactory(signerUser2.address);
      const tx = await dutchContract
        .connect(signerUser2)
        .createAuction(
          veEqualID,
          contractVeEqual.target,
          contractERC20.target,
          valueInWei(10),
          valueInWei(2),
          86400 * 10
        );
      const receipt = await tx.wait();
      const auctionAddress = receipt.logs[1].args[0];
      auction = await ethers.getContractAt(
        "dutchAuction_veNFT",
        auctionAddress
      );

      await checkPrice(valueInWei(10));
      await time.increase(86400);
      await checkPrice(valueInWei(9.2));
      await time.increase(86400);
      await checkPrice(valueInWei(8.4));
      await time.increase(86400 * 100);
      await checkPrice(valueInWei(1.5));
      await dutchContract.connect(owner).setRatio(500);
      await checkPrice(valueInWei(0.5));
      await expect(dutchContract.connect(owner).setRatio(300)).to.be.rejected;
      await expect(dutchContract.connect(signerUser2).setRatio(600)).to.be
        .rejected;
    }),
    it("Cancel it", async () => {
      await auction.connect(owner).cancelOffer();
      await contractERC20
        .connect(buyer)
        .approve(auction.target, valueInWei(100));
      const ownerNFT = await contractVeEqual.ownerOf(veEqualID);
      const data = await auction.s_CurrentAuction();
      expect(data[7]).to.be.false;
      await expect(auction.connect(buyer).buyNFT()).to.be.rejected;
      await expect(auction.connect(owner).cancelOffer()).to.be.rejected;
      expect(ownerNFT).to.be.equal(owner.address);
    });
});
