require("@nomiclabs/hardhat-waffle")
require('hardhat-contract-sizer')

if (process.env.GAS_REPORT === 'yes') {
  require("hardhat-gas-reporter");
}

const env = require('./allEnvs').envJson

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
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: env.coinmarketcap
  }
};

