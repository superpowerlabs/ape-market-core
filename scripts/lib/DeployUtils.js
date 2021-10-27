const path = require('path')
const fs = require('fs-extra')
const {expect, assert} = require("chai")
const {Contract} = require('@ethersproject/contracts')

const ABIs = {
  ApeRegistry: require('../../artifacts/contracts/registry/ApeRegistry.sol/ApeRegistry.json').abi,
  Profile: require('../../artifacts/contracts/user/Profile.sol/Profile.json').abi,
  SaleSetupHasher: require('../../artifacts/contracts/sale/SaleSetupHasher.sol/SaleSetupHasher.json').abi,
  SaleDB: require('../../artifacts/contracts/sale/SaleDB.sol/SaleDB.json').abi,
  SaleData: require('../../artifacts/contracts/sale/SaleData.sol/SaleData.json').abi,
  SaleFactory: require('../../artifacts/contracts/sale/SaleFactory.sol/SaleFactory.json').abi,
  TokenRegistry: require('../../artifacts/contracts/sale/TokenRegistry.sol/TokenRegistry.json').abi,
  SANFT: require('../../artifacts/contracts/nft/SANFT.sol/SANFT.json').abi,
  SANFTManager: require('../../artifacts/contracts/nft/SANFTManager.sol/SANFTManager.json').abi,
  MultiSigRegistryOwner: require('../../artifacts/contracts/registry/MultiSigRegistryOwner.sol/MultiSigRegistryOwner.json').abi,
  TetherMock: require('../../artifacts/contracts/test/TetherMock.sol/TetherMock.json').abi
}

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
    const Contract = await this.ethers.getContractFactory(contractName)
    consoleLog("Deploying", contractName, ...args)
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
      usdtOwner,
      forProduction,
      signersList,
      validity
    } = conf

    const apeRegistry = await this.deployContract('ApeRegistry')
    const registryAddress = apeRegistry.address

    const profile = await this.deployContract('Profile')
    const saleSetupHasher = await this.deployContract('SaleSetupHasher')
    const saleDB = await this.deployContract('SaleDB', registryAddress)
    const saleData = await this.deployContract('SaleData', registryAddress, apeWallet)
    const saleFactory = await this.deployContract('SaleFactory', registryAddress, operators[0])
    const tokenRegistry = await this.deployContract('TokenRegistry', registryAddress)
    const sANFT = await this.deployContract('SANFT', registryAddress)
    const sANFTManager = await this.deployContract('SANFTManager', registryAddress)
    const multiSigRegistryOwner = await this.deployContract('MultiSigRegistryOwner', registryAddress, signersList, validity)

    await expect(await apeRegistry.register([
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
    ])).emit(apeRegistry, "ChangePushedToSubscribers")

    // after the first setup, only the multiSig owner can change it
    await apeRegistry.setMultiSigOwner(multiSigRegistryOwner.address)

    let uSDT

    if (!forProduction) {
      uSDT = await this.deployContractBy("TetherMock", usdtOwner || (await ethers.getSigners())[0])
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
      multiSigRegistryOwner,
      apeWallet,
      operators,
      uSDT
    }
  }

  async initAndDeployTestnet(conf = {}) {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.

    const ethers = this.ethers
    const chainId = (await ethers.provider.getNetwork()).chainId
    // console.log(await ethers.provider.getNetwork())

    conf = Object.assign(config[chainId], conf)

    if (conf == null) {
      console.info("Configuration for ", chainId, " not found in config/index.js")
      return
    }

    let {
      apeWallet,
      operators,
      usdtOwner,
      signersList,
      validity
    } = conf

    let apeRegistry,
        profile,
        saleSetupHasher,
        saleDB,
        saleData,
        saleFactory,
        tokenRegistry,
        sANFT,
        sANFTManager,
        multiSigRegistryOwner,
        uSDT

    function previous(what) {
      return 'PREVIOUS_' + (
              chainId === 3 ? 'ROPSTEN_'
                  : chainId === 97 ? 'BSCTESTNET_'
                      : ''
          )
          + what
    }

    const previousContracts = previous('DEPLOYED')

    const addr = (process.env[previousContracts] || '').split(',')
    if (addr.length && chainId !== 1337) {
      if (addr[0]) {
        console.log('ApeRegistry previously deployed')
        apeRegistry = new Contract(addr[0], ABIs.ApeRegistry, ethers.provider)
      }
      if (addr[1]) {
        console.log('Profile previously deployed')
        profile = new Contract(addr[1], ABIs.Profile, ethers.provider)
      }
      if (addr[2]) {
        console.log('SaleSetupHasher previously deployed')
        saleSetupHasher = new Contract(addr[2], ABIs.SaleSetupHasher, ethers.provider)
      }
      if (addr[3]) {
        console.log('SaleDB previously deployed')
        saleDB = new Contract(addr[3], ABIs.SaleDB, ethers.provider)
      }
      if (addr[4]) {
        console.log('SaleData previously deployed')
        saleData = new Contract(addr[4], ABIs.SaleData, ethers.provider)
      }
      if (addr[5]) {
        console.log('SaleFactory previously deployed')
        saleFactory = new Contract(addr[5], ABIs.SaleFactory, ethers.provider)
      }
      if (addr[6]) {
        console.log('TokenRegistry previously deployed')
        tokenRegistry = new Contract(addr[6], ABIs.TokenRegistry, ethers.provider)
      }
      if (addr[7]) {
        console.log('SANFT previously deployed')
        sANFT = new Contract(addr[7], ABIs.SANFT, ethers.provider)
      }
      if (addr[8]) {
        console.log('SANFTManager previously deployed')
        sANFTManager = new Contract(addr[8], ABIs.SANFTManager, ethers.provider)
      }
      if (addr[9]) {
        console.log('MultiSigRegistryOwner previously deployed')
        multiSigRegistryOwner = new Contract(addr[9], ABIs.MultiSigRegistryOwner, ethers.provider)
      }
    }

    apeRegistry = apeRegistry || await this.deployContract('ApeRegistry')
    let registryAddress = apeRegistry.address

    profile = profile || await this.deployContract('Profile')
    saleSetupHasher = saleSetupHasher || await this.deployContract('SaleSetupHasher')
    saleDB = saleDB || await this.deployContract('SaleDB', registryAddress)
    saleData = saleData || await this.deployContract('SaleData', registryAddress, apeWallet)
    saleFactory = saleFactory || await this.deployContract('SaleFactory', registryAddress, operators[0])
    tokenRegistry = tokenRegistry || await this.deployContract('TokenRegistry', registryAddress)
    sANFT = sANFT || await this.deployContract('SANFT', registryAddress)
    sANFTManager = sANFTManager || await this.deployContract('SANFTManager', registryAddress)
    multiSigRegistryOwner = multiSigRegistryOwner || await this.deployContract('MultiSigRegistryOwner', registryAddress, signersList, validity)

    const signers = await ethers.getSigners()

    await expect(await apeRegistry.connect(signers[0]).register([
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
    ], {
      gasLimit: '1000000'
    })).emit(apeRegistry, "ChangePushedToSubscribers")

    // after the first setup, only the multiSig owner can change it
    await apeRegistry.connect(signers[0]).setMultiSigOwner(multiSigRegistryOwner.address)

    const previousTokens = previous('TOKENS')
    if (process.env[previousTokens]) {
      console.log('USDT previously deployed')
      const addr = process.env[previousTokens].split(',')[0]
      uSDT = new Contract(addr, ABIs.TetherMock, ethers.provider)
    }

    //
    if (usdtOwner) {
      uSDT = uSDT || await this.deployContractBy("TetherMock", usdtOwner)
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
      multiSigRegistryOwner,
      apeWallet,
      operators,
      uSDT
    }
  }

  localChain(chainId) {
    return chainId === 1337 || chainId === 5777
  }

  async currentChainId() {
    return (await this.ethers.provider.getNetwork()).chainId
  }

  async saveConfig(chainId, data, extraData) {
    const jsonpath = path.resolve(configPath, 'deployed.json')
    if (!(await fs.pathExists(jsonpath))) {
      await fs.writeFile(jsonpath, '{}')
    }
    const deployed = require(jsonpath)
    if (this.localChain(chainId) || !deployed[chainId]
        // legacy:
        || Array.isArray(deployed[chainId])) {
      deployed[chainId] = {
        paymentTokens: {},
        sellingTokens: {}
      }
    }
    if (!deployed[chainId].paymentTokens) {
      deployed[chainId].paymentTokens = {}
    }
    if (!deployed[chainId].sellingTokens) {
      deployed[chainId].sellingTokens = {}
    }
    deployed[chainId].ApeRegistry = data.apeRegistry
    if (extraData) {
      deployed[chainId].paymentTokens = Object.assign(deployed[chainId].paymentTokens,
          (extraData || {}).paymentTokens)
      deployed[chainId].sellingTokens = Object.assign(deployed[chainId].sellingTokens,
          (extraData || {}).sellingTokens)
    }
    await fs.writeFile(jsonpath, JSON.stringify(deployed, null, 2))
  }

  async deployERC20(owner, name, ticker) {
    return await this.deployContractBy("ERC20Token", owner, name, ticker)
  }

  async initAndDeployToken(conf = {}) {
    const ethers = this.ethers
    const chainId = (await ethers.provider.getNetwork()).chainId

    let {
      signerIndex,
      tokenName,
      tokenAbbr,
      isTether
    } = conf

    const owner = (await ethers.getSigners())[signerIndex]

    let token
    if (isTether) {
      tokenName = 'Tether USDT'
      tokenAbbr = 'USDT'
      token = await this.deployContractBy("TetherMock", owner)
    } else {
      token = await this.deployERC20(owner, tokenName, tokenAbbr)
    }
    return {
      chainId,
      name: tokenName,
      abbr: tokenAbbr,
      owner: owner.address,
      token: token.address
    }
  }

}

module.exports = DeployUtils
