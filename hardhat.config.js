require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const PRIVATE_KEY =
  "5e5fdabc974affe53725b4ce786a492c41bbf7678bf8e456da881a5c1f8d84ea";
module.exports = {
  solidity: {
    version: "0.8.21",
    settings: {
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
  },
};
