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

  joinOperatorsAndValidators(operators, validators) {
    const _operators = operators
    const _roles = []
    // all the operators should have role 1
    for (let i = 0 ; i < operators.length; i++) {
      _roles.push(1);
    }
    for (let i = 0; i < validators.length; i++) {
      let k = _operators.indexOf(validators[i])
      if (k != -1) { // if validator is also an operator
        _roles[k] |= 1 << 1;
      } else {
        _operators.push(validators[i]);
        _roles.push(1 << 1)
      }
    }
    return [_operators, _roles]
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

    let USDT, USDC
    if (chainId === 1337 || chainId === 5777 || chainId === 4) {
      USDT = await this.deployContract("TetherMock")
      USDC = await this.deployERC20('USDC', 'USDC')
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
      USDT,
      USDC
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
    if (chainId === 1337 || !deployed[chainId]
        // legacy:
        || Array.isArray(deployed[chainId]))
    {
      deployed[chainId] = {
        paymentTokens: {}
      }
    }
    deployed[chainId].ApeRegistry = data.apeRegistry
    if (chainId === 1337) {
      deployed[chainId].paymentTokens.USDT = data.USDT
      deployed[chainId].paymentTokens.USDC = data.USDC
    }
    await fs.writeFile(jsonpath, JSON.stringify(deployed, null, 2))
  }

  async deployERC20(owner, name, ticker) {
    return await this.deployContract("ERC20Token", name, ticker)
  }
}

module.exports = DeployUtils
