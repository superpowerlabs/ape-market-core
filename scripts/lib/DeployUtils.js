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

    // for app debugging:
    let uSDT
    let uSDC
    let abcToken // owned by signers[1]
    let mnoToken // owned by signers[3]
    let xyzToken // owned by signers[4]
    if (this.localChain(chainId) || chainId === 4) {
      const [owner, seller1, operator, seller3, seller4] = await ethers.getSigners()
      uSDT = await this.deployContract("TetherMock")
      uSDC = await this.deployERC20(owner, 'USDC', 'USDC')
      if (this.localChain(chainId)) {
        abcToken = await this.deployERC20(seller1, 'Abc Token', 'ABC')
        mnoToken = await this.deployERC20(seller3, 'Mno Token', 'MNO')
        xyzToken = await this.deployERC20(seller4, 'Xyz Token', 'XYZ')
      }
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
      USDT: uSDT,
      USDC: uSDC,
      ABC: abcToken,
      MNO: mnoToken,
      XYZ: xyzToken
    }
  }

  localChain(chainId) {
    return chainId === 1337 || chainId === 5777
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
    if (this.localChain(chainId) || !deployed[chainId]
        // legacy:
        || Array.isArray(deployed[chainId]))
    {
      deployed[chainId] = {
        paymentTokens: {}
      }
    }
    deployed[chainId].ApeRegistry = data.apeRegistry
    if (this.localChain(chainId)) {
      for (let k of 'USDT,USDC,ABC,MNO,XYZ'.split(',')) {
        deployed[chainId].paymentTokens[k] = data[k]
      }
    }
    await fs.writeFile(jsonpath, JSON.stringify(deployed, null, 2))
  }

  async deployERC20(owner, name, ticker) {
    return await this.deployContractBy("ERC20Token", owner, name, ticker)
  }
}

module.exports = DeployUtils
