const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

const saleJson = require('../src/artifacts/contracts/sale/Sale.sol/Sale.json')

describe.only("SaleFactory", async function () {

  let Token
  let sellingToken
  let Tether
  let tether
  let SAStorage
  let storage
  let SAToken
  let satoken
  let SaleFactory
  let factory
  let Sale
  let sampleSale

  let saleSetup
  let saleVestingSchedule

  let owner, factoryAdmin, newFactoryAdmin, seller, buyer, buyer2
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, factoryAdmin, newFactoryAdmin, fakeSale, seller, buyer, buyer2] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {

    saleSetup = {
      satoken: addr0,
      minAmount: 1,
      capAmount: 10,
      remainingAmount: 0,
      pricingToken: 1,
      pricingPayment: 2,
      sellingToken: addr0,
      paymentToken: addr0,
      owner: seller.address,
      tokenListTimestamp: 0,
      tokenFeePercentage: 1,
      paymentFeePercentage: 1,
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

    Sale = await ethers.getContractFactory("Sale")
    sampleSale = await Sale.deploy()
    await sampleSale.deployed()

    SAStorage = await ethers.getContractFactory("SAStorage")
    storage = await SAStorage.deploy()
    await storage.deployed()

    SaleFactory = await ethers.getContractFactory("SaleFactory")
    factory = await SaleFactory.deploy(sampleSale.address)
    await factory.deployed()
    factory.grantFactoryRole(factoryAdmin.address)

    SAToken = await ethers.getContractFactory("SAToken")
    satoken = await SAToken.deploy(factory.address, storage.address)
    await satoken.deployed()

    Token = await ethers.getContractFactory("Token")
    sellingToken = await Token.connect(seller).deploy("Abc Token", "ABC")
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
      assert.isTrue(await factory.hasRole(factory.FACTORY_ADMIN_ROLE(), factoryAdmin.address))
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

    it.only("should create a new sale", async function () {

      await expect(factory.connect(factoryAdmin).newSale(saleSetup,saleVestingSchedule))
          .to.emit(factory, "NewSale")
      const saleAddress = await factory.lastSale()
      assert.isTrue(await factory.isLegitSale(saleAddress))
      const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      assert.isTrue(await sale.hasRole(await sale.SALE_OWNER_ROLE(), saleSetup.owner))
      assert.isTrue(await factory.isLegitSale(saleAddress))
      assert.equal((await factory.getAllSales())[0], saleAddress)
      assert.equal(await factory.getSale(0), saleAddress)

    })

    it("should throw if trying to create a sale as contract owner", async function () {

      await assertThrowsMessage(
          factory.newSale(saleSetup,saleVestingSchedule),
          'is missing role')

    })

    it("should create a not legit sale to check the gas consumption", async function () {
      Sale = await ethers.getContractFactory("Sale")
      sale = await Sale.deploy()
      await sale.deployed()
    })

  })

})
