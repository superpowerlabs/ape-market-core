const path = require('path')
const fs = require('fs-extra')

const configPath = path.resolve(__dirname, '../../config')
const config = require(configPath)

const addr0 = '0x0000000000000000000000000000000000000000'

function consoleLog(...args) {
  if (process.env.VERBOSE_LOG) {
    console.log(...args)
  }
}

class DeployUtils {

  constructor(ethers) {
    this.ethers = ethers
  }

  async deployContract(contractName, ...args) {
    consoleLog("Deploying", contractName)
    const Contract = await this.ethers.getContractFactory(contractName)
    const contract = await Contract.deploy(...args)
    await contract.deployed()
    consoleLog("Deployed at", contract.address)
    return contract
  }

  async deployContractBy(contractName, owner, ...args) {
    consoleLog("Deploying", contractName)
    const Contract = await this.ethers.getContractFactory(contractName)
    const contract = await Contract.connect(owner).deploy(...args)
    await contract.deployed()
    consoleLog("Deployed at", contract.address)
    return contract
  }

  async initAndDeploy(conf = {}) {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.

    const ethers = this.ethers
    const chainId = (await ethers.provider.getNetwork()).chainId
    conf = Object.assign(config[chainId], conf)

    if (conf == null) {
      console.info("Configuration for ", chainId, " not found in config/index.js")
      return
    }

    let {
      apeWallet,
      operators,
      feePoints
    } = conf

    const apeRegistry = await this.deployContract('ApeRegistry')
    const registryAddress = apeRegistry.address

    const profile = await this.deployContract('Profile')
    const saleSetupHasher = await this.deployContract('SaleSetupHasher')
    const saleDB = await this.deployContract('SaleDB', registryAddress)
    const saleData = await this.deployContract('SaleData', registryAddress, apeWallet)
    const saleFactory = await this.deployContract('SaleFactory', registryAddress, operators)
    const tokenRegistry = await this.deployContract('TokenRegistry', registryAddress)
    const sANFT = await this.deployContract('SANFT', registryAddress)
    const sANFTManager = await this.deployContract('SANFTManager', registryAddress, apeWallet, feePoints)

    await apeRegistry.register([
      'Profile',
      'SaleSetupHasher',
      'SaleDB',
      'SaleData',
      'SaleFactory',
      'SANFT',
      'SANFTManager',
      'TokenRegistry'
    ].map(n => ethers.utils.id(n)), [
      profile.address,
      saleSetupHasher.address,
      saleDB.address,
      saleData.address,
      saleFactory.address,
      sANFT.address,
      sANFTManager.address,
      tokenRegistry.address
    ])

    await apeRegistry.updateAllContracts()

    let tetherMock
    if (chainId === 1337 || chainId === 5777 || chainId === 4) {
      tetherMock = await this.deployContract("TetherMock")
    }

    return {
      apeRegistry,
      profile,
      saleSetupHasher,
      saleData,
      saleDB,
      saleFactory,
      sANFT,
      sANFTManager,
      tokenRegistry,
      apeWallet,
      operators,
      tetherMock
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
    if (!deployed[chainId] || Array.isArray(deployed[chainId])) {
      deployed[chainId] = {}
    }
    deployed[chainId].ApeRegistry = data.apeRegistry
    deployed[chainId].TetherMock = data.tetherMock
    await fs.writeFile(jsonpath, JSON.stringify(deployed, null, 2))
  }
}

module.exports = DeployUtils
