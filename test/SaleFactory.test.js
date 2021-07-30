const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

const saleJson = require('../src/artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SaleFactory", async function () {

  let ERC20Token
  let sellingToken
  let Tether
  let tether
  let SAStorage
  let storage
  let SAToken
  let satoken
  let SaleFactory
  let factory
  let SaleData
  let saleData

  let saleSetup
  let saleVestingSchedule

  let owner, factoryAdmin, newFactoryAdmin, apeWallet, seller, buyer, buyer2
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, factoryAdmin, newFactoryAdmin, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {

    Profile = await ethers.getContractFactory("Profile")
    profile = await Profile.deploy()
    await profile.deployed()

    SAStorage = await ethers.getContractFactory("SAStorage")
    storage = await SAStorage.deploy()
    await storage.deployed()

    SaleData = await ethers.getContractFactory("SaleData")
    saleData = await SaleData.deploy()
    await saleData.deployed()

    SaleFactory = await ethers.getContractFactory("SaleFactory")
    factory = await SaleFactory.deploy()
    await factory.deployed()
    saleData.grantLevel(await saleData.ADMIN_LEVEL(), factory.address)
    factory.grantLevel(await factory.FACTORY_ADMIN_LEVEL(), factoryAdmin.address)

    SAToken = await ethers.getContractFactory("SAToken")
    satoken = await SAToken.deploy(factory.address, storage.address, profile.address)
    await satoken.deployed()

    ERC20Token = await ethers.getContractFactory("ERC20Token")
    sellingToken = await ERC20Token.connect(seller).deploy("Abc Token", "ABC")
    await sellingToken.deployed()

    Tether = await ethers.getContractFactory("TetherMock")
    tether = await Tether.deploy()
    await tether.deployed()
    await (await tether.transfer(buyer.address, 40000)).wait()
    await (await tether.transfer(buyer2.address, 50000)).wait()

  }

  describe('#constructor & #updateFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the apeFactory is correctly set", async function () {
      assert.equal((await factory.levels(factoryAdmin.address)).toNumber(), (await factory.FACTORY_ADMIN_LEVEL()).toNumber())
    })

  })

  describe('#newSale', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()

      saleSetup = {
        satoken: satoken.address,
        minAmount: 100,
        capAmount: 20000,
        remainingAmount: 0,
        pricingToken: 1,
        pricingPayment: 2,
        sellingToken: sellingToken.address,
        paymentToken: tether.address,
        owner: seller.address,
        tokenListTimestamp: 0,
        tokenFeePercentage: 5,
        paymentFeePercentage: 10,
        tokenIsTransferable: true
      };
      saleVestingSchedule = [
        {
          timestamp: 10,
          percentage: 50
        },
        {
          timestamp: 1000,
          percentage: 100
        }]

    })

    it("should create a new sale", async function () {

      assert.equal(await factory.lastSale(), addr0)

      await expect(factory.connect(factoryAdmin).newSale(saleSetup, saleVestingSchedule, apeWallet.address, saleData.address))
          .emit(factory, "NewSale")
      const saleAddress = await factory.lastSale()
      const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      assert.isTrue(await factory.isLegitSale(saleAddress))
      assert.equal((await factory.getAllSales())[0], saleAddress)
      assert.equal(await factory.getSale(0), saleAddress)

    })

    it("should throw if trying to create a sale as contract owner", async function () {

      await assertThrowsMessage(
          factory.newSale(saleSetup, saleVestingSchedule, apeWallet.address, saleData.address),
          'LevelAccess: caller not authorized')

    })

  })

})
