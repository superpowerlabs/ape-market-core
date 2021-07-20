const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

const saleJson = require('../src/artifacts/contracts/sale/Sale.sol/Sale.json')

describe.only("SAToken", async function () {

  let Token
  let sellingToken
  let Tether
  let tether
  let SAStorage
  let storage
  let SAToken
  let satoken
  let Sale
  let sale
  let fakeSale
  let SaleFactory
  let factory
  let PAUSER_ROLE
  let saleAddress

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

    SAStorage = await ethers.getContractFactory("SAStorage")
    storage = await SAStorage.deploy()
    await storage.deployed()

    SaleFactory = await ethers.getContractFactory("SaleFactory")
    factory = await SaleFactory.deploy()
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

    const saleSetup = {
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
    const saleVestingSchedule = [
      {
        timestamp: 10,
        percentage: 50
      },
      {
        timestamp: 1000,
        percentage: 100
      }]


    await factory.connect(factoryAdmin).newSale(
        saleSetup,
        saleVestingSchedule
    )

    saleAddress = await factory.lastSale()
    sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)

    Sale = await ethers.getContractFactory("Sale")
    fakeSale = await Sale.deploy(saleSetup, saleVestingSchedule)
    await fakeSale.deployed()

    await storage.grantRole(await storage.MANAGER_ROLE(), satoken.address)
  }

  describe('#constructor & #updateFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the apeFactory is correctly set", async function () {
      assert.equal((await satoken.factory()), factory.address)
    })

    it("should set and verify that newFactory is the new factory", async function () {
      await satoken.updateFactory(newFactoryAdmin.address)
      assert.equal((await satoken.factory()), newFactoryAdmin.address)
    })

  })

  describe('#mint', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should allow saleMock to mint a token ", async function () {

      await expect(sale.mintToken(buyer.address, 100))
          .to.emit(satoken, 'Transfer')
          .withArgs(addr0, buyer.address, 0)
      assert.equal(await satoken.ownerOf(0), buyer.address)

      await expect(sale.mintToken(buyer2.address, 50))
          .to.emit(satoken, 'Transfer')
          .withArgs(addr0, buyer2.address, 1)
      assert.equal(await satoken.ownerOf(1), buyer2.address)
    })

    it("should throw if a not legit sale try to mint a token", async function () {

      await assertThrowsMessage(
          fakeSale.mintToken(buyer.address, 100),
          'SAToken: Only legit sales can mint its own NFT!')

    })

    it("should throw if a non-contract try to mint a token", async function () {

      await assertThrowsMessage(
          satoken.connect(buyer2).mint(buyer.address, 100),
          'SAToken: The caller is not a contract')

    })
  })

})
