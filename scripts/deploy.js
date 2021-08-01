// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const DeployUtils = require('./lib/DeployUtils')

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.

  const deployUtils = new DeployUtils(hre.ethers)
  const chainId = await deployUtils.currentChainId()
  const data = await deployUtils.initAndDeploy()

  console.log(data)
  if (process.env.SAVE_DEPLOYED_ADDRESSES) {
    await deployUtils.saveConfig(chainId, data)
  }

}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
