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


  let owner;
  let signer1;
  let signerUser2;
  let holderEQUAL;
  let contractFactoryV2;
  let contractOffersV2;
  let contractERC20;
  let contractERC721;

  this.beforeAll(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    signer1 = signers[1];
    signerUser2 = signers[2];
  });
  beforeEach(async function () {
    
    const factory = await ethers.getContractFactory("DebitaV2Factory");
    contractFactoryV2 = await factory.deploy();
    const erc20 = await ethers.getContractFactory("ERC20DEBITA");
    contractOffersV2 = await ethers.getContractFactory("DebitaV2Offers");
    contractERC20 = await erc20.attach(equalAddress);
    const accounts = "0x89A7c531178CD6EB01994361eFc0d520a3a702C6";
    holderEQUAL = await ethers.getImpersonatedSigner(accounts);

    await contractERC20.connect(holderEQUAL).approve(contractFactoryV2.target, valueInWei(10000))
     
    await contractERC20.connect(holderEQUAL).transfer(signerUser2.address, valueInWei(100))

    await contractERC20.connect(signerUser2).approve(contractFactoryV2.target, valueInWei(10000))
     
    

  });
  

 it("Create & Cancel Lending Offer  -- with $EQUAL (ERC-20)", async () => {
  const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
    equalAddress,
    equalAddress,
    100,
    100,
    false,
    false,
    10,
    0,
    1,
    86400,
    true
    );
   // Get events
    const receipt = await tx.wait()
    const createdOfferAddress = receipt.logs[1].args[1];

    //  --- Check if funding got there ---
    expect(await contractFactoryV2.isSenderAnOffer(createdOfferAddress)).to.be.true;
    expect(await contractERC20.balanceOf(createdOfferAddress)).to.be.equal(100);
    // ------

    // Cancel and check if value gets back
    const offerContract = await contractOffersV2.attach(createdOfferAddress);
    expect(await offerContract.isActive()).to.be.true;
    await offerContract.connect(holderEQUAL).cancelOffer();
    expect(await contractERC20.balanceOf(createdOfferAddress)).to.be.equal(0);
    expect(await offerContract.isActive()).to.be.false;
    await expect( offerContract.connect(holderEQUAL).cancelOffer()).to.be.revertedWith("Offer is not active.");

 }),

 it("Accept Offer & Create loan -- with $EQUAL (ERC-20)", async () => {
  const tx = await contractFactoryV2.connect(holderEQUAL).createOfferV2(
    equalAddress,
    equalAddress,
    100,
    100,
    false,
    false,
    10,
    0,
    1,
    86400,
    true
    );
   // Get events
    const receipt = await tx.wait()
    const createdOfferAddress = receipt.logs[1].args[1];

    const offerContract = await contractOffersV2.attach(createdOfferAddress);
    const tx_Accept =await offerContract.connect(holderEQUAL).acceptOfferAsBorrower(10);

    const receipt_accept = await tx_Accept.wait()
   console.log(receipt_accept.logs[1].args);
    
 })
});
