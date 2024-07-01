require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const PRIVATE_KEY =
  "f2dea7d23020656cd2ec84cb74235aefeb70229106582253d18bb46fb1667cc7";

const PRIVATE_KEY2 = "0x00";

module.exports = {
  solidity: {
    version: "0.8.21",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000, // Adjust the number of runs as per your requirements
      },
    },
    allowUnlimitedContractSize: true,
  },
  sourcify: {
    enabled: true,
  },
  etherscan: {
    apiKey: "M29EN5FD9FXS2HQQVJE18JBPV4QFIJG4CJ",
  },
  networks: {
    fantom: {
      url: `https://rpc.ankr.com/fantom`,
      accounts: [PRIVATE_KEY],
    },
    base: {
      url: "https://mainnet.base.org",
      accounts: [PRIVATE_KEY],
    },
  },
};
