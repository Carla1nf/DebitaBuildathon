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
  const aeroAddress = "0x940181a94A35A4569E4529A3CDfB74e38FD98631";
  const AeroOracle = "0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0";
  const veNFTAddress = "0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4";

  let owner;
  let signer1;
  let signerUser2;
  let holderEQUAL;
  let contractVeEqual;
  let veEqualID;
  let poolFactory;
  let poolContract;

  this.beforeAll(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    signer1 = signers[1];
    signerUser2 = signers[2];
    await owner.sendTransaction({
      to: "0x9C798fcf3D39E009FAF03c6f1411A3579CCA03a8",
      value: ethers.parseUnits("2", "ether"),
    });
  });

  beforeEach(async function () {
    const dutchFactory = await ethers.getContractFactory(
      "auctionFactoryDebita"
    );
    const erc20 = await ethers.getContractFactory("ERC20DEBITA");
    const poolABI = await ethers.getContractFactory("debitaMultiPool");

    const accounts = "0x9C798fcf3D39E009FAF03c6f1411A3579CCA03a8";
    holderEQUAL = await ethers.getImpersonatedSigner(accounts);

    const veEqualContract = await ethers.getContractFactory("veEQUAL");
    const poolFactoryABI = await ethers.getContractFactory(
      "debitaMultiPoolFactory"
    );
    poolFactory = await poolFactoryABI.deploy();
    await poolFactory.setOraclePerToken(aeroAddress, AeroOracle);
    contractVeEqual = await veEqualContract.attach(veNFTAddress);

    contractERC20 = await erc20.attach(aeroAddress);
    await contractERC20
      .connect(holderEQUAL)
      .approve(contractVeEqual.target, valueInWei(10000));

    await contractERC20
      .connect(holderEQUAL)
      .approve(poolFactory.target, valueInWei(1000));
    const poolAddress = await poolFactory
      .connect(holderEQUAL)
      .createPool(
        aeroAddress,
        aeroAddress,
        5000,
        300,
        86400 * 10,
        valueInWei(10)
      );
    const receipt = await poolAddress.wait();
    const address = receipt.logs[receipt.logs.length - 1].args[0];
    poolContract = await poolABI.attach(address);
  }),
    it("Check price decreasing", async function () {
      const answer = await poolContract.getDataFeed_Collateral();
      const answerPrinciple = await poolContract.getDataFeed_Principle();
      const checkSequencer = await poolContract.checkSequencer();

      expect(checkSequencer).to.be.true;
      expect(answer > 0).to.be.true;
      expect(answerPrinciple).to.be.equal(answer);
    });
});
