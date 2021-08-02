const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SaleFactory", async function () {

  let Profile
  let profile
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
  let SATokenExtras
  let tokenExtras

  let saleSetup
  let saleVestingSchedule

  let owner, validator, factoryAdmin, apeWallet, seller, buyer, buyer2
  let addr0 = '0x0000000000000000000000000000000000000000'


  async function getSignatureByValidator(saleId, setup, schedule) {
    const hash = await factory.encodeForSignature(saleId, setup, schedule)
    const signingKey = new ethers.utils.SigningKey('0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d')
    const signedDigest = signingKey.signDigest(hash)
    return ethers.utils.joinSignature(signedDigest)
  }

  before(async function () {
    [owner, validator, factoryAdmin, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()
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
    saleData = await SaleData.deploy(apeWallet.address)
    await saleData.deployed()

    SaleFactory = await ethers.getContractFactory("SaleFactory")
    factory = await SaleFactory.deploy(saleData.address, validator.address)
    await factory.deployed()
    await saleData.grantLevel(await saleData.ADMIN_LEVEL(), factory.address)
    await factory.grantLevel(await factory.OPERATOR_LEVEL(), factoryAdmin.address)

    SATokenExtras = await ethers.getContractFactory("SATokenExtras")
    tokenExtras = await SATokenExtras.deploy(profile.address)
    await tokenExtras.deployed()

    SAToken = await ethers.getContractFactory("SAToken")
    satoken = await SAToken.deploy(factory.address, tokenExtras.address)
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
      assert.equal((await factory.levels(factoryAdmin.address)).toNumber(), (await factory.OPERATOR_LEVEL()).toNumber())
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

      let saleId = await saleData.nextSaleId()

      await factory.connect(factoryAdmin).approveSale(saleId)

      let signature = getSignatureByValidator(saleId, saleSetup, saleVestingSchedule)

      await expect(factory.connect(seller).newSale(saleId, saleSetup, saleVestingSchedule, signature))
          .emit(factory, "NewSale")
      const saleAddress = await saleData.getSaleAddressById(saleId)
      const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      assert.isTrue(await factory.isLegitSale(saleAddress))

    })

    it("should throw if trying to create a sale without a pre-approval", async function () {

      let saleId = await saleData.nextSaleId()
      let signature = getSignatureByValidator(saleId, saleSetup, saleVestingSchedule)

      await assertThrowsMessage(
          factory.newSale(saleId, saleSetup, saleVestingSchedule, signature),
          'SaleData: invalid id')

    })

    it("should throw if trying to create a sale with a modified setup", async function () {

      let saleId = await saleData.nextSaleId()

      let signature = getSignatureByValidator(saleId, saleSetup, saleVestingSchedule)

      await factory.connect(factoryAdmin).approveSale(saleId)

      saleSetup.capAmount = 3450000

      await assertThrowsMessage(
          factory.newSale(saleId, saleSetup, saleVestingSchedule, signature),
          'SaleFactory: invalid signature or modified params')

    })


  })

})
