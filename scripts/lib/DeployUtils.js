const path = require('path')
const fs = require('fs-extra')

const configPath = path.resolve(__dirname, '../../src/config')
const config = require(configPath)

const addr0 = '0x0000000000000000000000000000000000000000'

class DeployUtils {

  constructor(ethers) {
    this.ethers = ethers
  }

  async initAndDeploy() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.

    const ethers = this.ethers

    const chainId = (await ethers.provider.getNetwork()).chainId
    const signers = await ethers.getSigners();

    let tetherAddress

    let tetherOwner = config.tether[chainId]
    let apeWalletAddress = config.apeWallet
    let factoryAdminAddress = config.factoryAdmin

    if (chainId === 1337) {
      tetherOwner = signers[1]
      const Tether = await ethers.getContractFactory('TetherMock');
      const tether = await Tether.connect(tetherOwner).deploy();
      await tether.deployed();
      tetherAddress = tether.address;
      apeWalletAddress = signers[6].address
      factoryAdminAddress = signers[7].address
    }

    const Profile = await ethers.getContractFactory('Profile')
    const profile = await Profile.deploy()
    await profile.deployed()

    const SAStorage = await ethers.getContractFactory('SAStorage')
    const storage = await SAStorage.deploy()
    await storage.deployed()

    const SaleData = await ethers.getContractFactory('SaleData')
    const saleData = await SaleData.deploy()
    await saleData.deployed()

    const SaleFactory = await ethers.getContractFactory('SaleFactory')
    const factory = await SaleFactory.deploy()
    await factory.deployed()

    await saleData.grantLevel(await saleData.ADMIN_LEVEL(), factory.address)
    await factory.grantLevel(await factory.FACTORY_ADMIN_LEVEL(), factoryAdminAddress)

    const SAToken = await ethers.getContractFactory('SAToken')
    const satoken = await SAToken.deploy(factory.address, storage.address, profile.address)
    await satoken.deployed()

    await storage.grantLevel(await storage.MANAGER_LEVEL(), satoken.address)

    const SATokenExtras = await ethers.getContractFactory('SATokenExtras')
    const manager = await SATokenExtras.deploy(
        satoken.address,
        storage.address,
        tetherAddress,
        config.feeAmount,
        apeWalletAddress
    )
    await manager.deployed()

    await satoken.grantLevel(await satoken.MANAGER_LEVEL(), manager.address)
    await storage.grantLevel(await storage.MANAGER_LEVEL(), manager.address)

    return {
      Profile: profile.address,
      SAStorage: storage.address,
      SaleData: saleData.address,
      SaleFactory: factory.address,
      SAToken: satoken.address,
      SATokenExtras: manager.address,
      tether: tetherAddress,
      tetherOwner: tetherOwner ? tetherOwner.address : addr0,
      factoryAdmin: factoryAdminAddress,
      apeWallet: apeWalletAddress
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
