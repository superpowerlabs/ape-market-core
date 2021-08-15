const path = require('path')
const fs = require('fs-extra')

const configPath = path.resolve(__dirname, '../../config')
const config = require(configPath)

const addr0 = '0x0000000000000000000000000000000000000000'

class DeployUtils {

  constructor(ethers) {
    this.ethers = ethers
  }

  async deployContract(contractName, ...args) {
    console.log("Deploying", contractName)
    const Contract = await this.ethers.getContractFactory(contractName)
    const contract = await Contract.deploy(...args)
    await contract.deployed()
    console.log("Deployed at", contract.address)
    return contract
  }

  async deployContractBy(contractName, owner, ...args) {
    console.log("Deploying", contractName)
    const Contract = await this.ethers.getContractFactory(contractName)
    const contract = await Contract.connect(owner).deploy(...args)
    await contract.deployed()
    console.log("Deployed at", contract.address)
    return contract
  }

  async initAndDeploy(conf = {}) {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.

    const ethers = this.ethers
    console.log(await ethers.provider.getNetwork())
    const chainId = (await ethers.provider.getNetwork()).chainId

    conf = Object.assign(config[chainId], conf)
    let {
      apeWallet,
      operators,
      validators,
      feePermillage
    } = conf

    const apeRegistry = await this.deployContract('ApeRegistry')
    const registryAddress = apeRegistry.address

    const profile = await this.deployContract('Profile')
    const saleSetupHasher = await this.deployContract('SaleSetupHasher')
    const saleData = await this.deployContract('SaleData', registryAddress, apeWallet)
    const saleFactory = await this.deployContract('SaleFactory', registryAddress, operators, validators)
    const tokenRegistry = await this.deployContract('TokenRegistry', registryAddress)
    const sANFT = await this.deployContract('SANFT', registryAddress)
    const sANFTManager = await this.deployContract('SANFTManager', registryAddress, apeWallet, feePermillage)

    await apeRegistry.register([
      'Profile',
      'SaleSetupHasher',
      'SaleData',
      'SaleFactory',
      'SANFT',
      'SANFTManager',
      'TokenRegistry'
    ], [
      profile.address,
      saleSetupHasher.address,
      saleData.address,
      saleFactory.address,
      sANFT.address,
      sANFTManager.address,
      tokenRegistry.address
    ])

    return {
      apeRegistry,
      profile,
      saleSetupHasher,
      saleData,
      saleFactory,
      sANFT,
      sANFTManager,
      tokenRegistry,
      apeWallet,
      operators,
      validators
    }
  }

  async currentChainId() {
    return (await this.ethers.provider.getNetwork()).chainId
  }

  async saveConfig(chainId, data) {
    const jsonpath = path.resolve(configPath, 'deployed.json')
    if (!(await fs.pathExists(jsonpath))) {
      await fs.writeFile(jsonpath, '{}')
    }
    const deployed = require(jsonpath)
    deployed[chainId] = data
    await fs.writeFile(jsonpath, JSON.stringify(deployed, null, 2))
  }

}

module.exports = DeployUtils
