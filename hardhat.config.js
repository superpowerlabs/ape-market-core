require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");


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
  solidity: "0.8.3",
  paths: {
    artifacts: './src/artifacts',
    contracts: "./src/contracts",
  },
  networks: {
    // hardhat: {
    //   chainId: 1337
    // },
    rinkeby: {
      url: "https://eth-rinkeby.alchemyapi.io/v2/JqxAXeT7b2jG4E--K1_4GJlmc_OP2nRe",
      accounts:["6a4aaa1d87e308cda1d88836b97d3a05381246eb1bf8742a54351712a9400739",
      "3779ce9bce6df6c16a8ac658fd7e3d9edce199406cf857cae400c9fb3b048854",
      "55c9efaad718cafb466b089129bb811ec065078fec3678772e3887c521203778",
      "c17f32e3d8ee66ba45a7aa692cb9fd09f60419b441de049e4c7819a05f12540f",
      "f61a6df835e097090f5a8b058bf7a04c84f169e305fb9ace5c044601ac54a207",
      "7bf4c608a5f297d083b243e2462991bd9839750ac99e9b8f5c213a8a904be931"
      ],
      gas: "auto",
    },
  },
  etherscan: {
    apiKey: "JUIG4RKJHKAAFTP46HIWHN9ABUEANCP6VW"
  }
};

