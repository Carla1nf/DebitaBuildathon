require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const PRIVATE_KEY = "80c3828afd1ecee38551b52bd0d71283c3897b53291edb18bbe0bb0237e99617"
module.exports = {
  solidity: {
    version: "0.8.21",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000, // Adjust the number of runs as per your requirements
      },
    },
    allowUnlimitedContractSize: true
  },
  networks: {
   
    fantom: {
      url: `https://rpc.ankr.com/fantom`,
      accounts: [PRIVATE_KEY]
    }
  }

};