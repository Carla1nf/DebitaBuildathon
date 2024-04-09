const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Lock", function () {
  it("Create Offer", async () => {
    const meme = await ethers.getContractFactory("BASEDTOKEN");
    const memeMainnet = await meme.deploy();
    await memeMainnet.renounceOwnership(100000);

    console.log("Meme: ", memeMainnet.target);
  });
});
