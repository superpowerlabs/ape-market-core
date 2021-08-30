// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const {expect, assert} = require("chai")
const DeployUtils = require('./lib/DeployUtils')
const Deployed = require('../config/deployed.json')
const {
  initEthers,
  signPackedData,
  assertThrowsMessage,
  addr0
} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')
const apeRegistryJson = require('../artifacts/contracts/registry/ApeRegistry.sol/ApeRegistry.json')

async function main() {

  const deployUtils = new DeployUtils(ethers)
  initEthers(ethers)
  const chainId = (await ethers.provider.getNetwork()).chainId

  let apeRegistry, profile

  [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()

  apeRegistryAddress = Deployed[chainId].ApeRegistry
  
  console.log(apeRegistryAddress)

  apeRegistry = new ethers.Contract(apeRegistryAddress, apeRegistryJson.abi, owner)

  // console.log(apeRegistry)

  profile = await apeRegistry.get(ethers.utils.id("Profile"))
  console.log(profile)
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
