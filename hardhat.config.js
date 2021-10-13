require('dotenv').config()
require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require('hardhat-contract-sizer')
const requireOrMock = require('require-or-mock')

if (process.env.GAS_REPORT === 'yes') {
  require("hardhat-gas-reporter");
}

const env = requireOrMock('env.json')

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.6",
  settings: {
    optimizer: {
      enabled: true,
      runs: 800 // << trying to reduce gas consumption for users
    }
  },
  paths: {
    // artifacts: './src/artifacts',
  },
  networks: {
    hardhat: {
      chainId: 1337,
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: false,
      timeout: 1800000
    },
    rinkeby: env.rinkeby,
    ropsten: process.env.TESTNET_OWNER ? {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [
        process.env.TESTNET_OWNER,
        process.env.TESTNET_APE_WALLET,
        process.env.TESTNET_OPERATOR,
        process.env.TESTNET_TETHER_OWNER
      ]
    } : {
      url: ''
    }
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: env.coinmarketcap
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_KEY
  }
};

