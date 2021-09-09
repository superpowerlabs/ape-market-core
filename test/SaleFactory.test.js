const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {assertThrowsMessage, addr0} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SaleFactory", async function () {

  const deployUtils = new DeployUtils(ethers)

  let apeRegistry
      , profile
      , saleSetupHasher
      , saleData
      , saleDB
      , saleFactory
      , sANFT
      , sANFTManager
      , tokenRegistry
      , sellingToken
      , tether
      , saleSetup
      , owner
      , validator
      , operator
      , apeWallet
      , seller
      , buyer
      , buyer2

  before(async function () {
    [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  function normalize(val, n = 6 /* tether */) {
    return '' + val + '0'.repeat(n)
  }

  async function initNetworkAndDeploy() {


    const results = await deployUtils.initAndDeploy({
      apeWallet: apeWallet.address,
      operators: [operator.address]
    })

    apeRegistry = results.apeRegistry
    profile = results.profile
    saleSetupHasher = results.saleSetupHasher
    saleData = results.saleData
    saleDB = results.saleDB
    saleFactory = results.saleFactory
    sANFT = results.sANFT
    sANFTManager = results.sANFTManager
    tokenRegistry = results.tokenRegistry
    tether = results.USDT

    sellingToken = await deployUtils.deployContract("ERC20Token", "Abc Token", "ABC")

    await (await tether.transfer(buyer.address, normalize(40000))).wait()
    await (await tether.transfer(buyer2.address, normalize(50000))).wait()

  }

  describe('#constructor', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the factory is correctly set", async function () {
      assert.isTrue(await saleFactory.isOperator(operator.address))
    })

  })

  describe('#updateOperators/revoke', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the operator is set", async function () {
      // adding operator&validator role
      await expect(saleFactory.setOperator(buyer.address, true))
          .emit(saleFactory, 'OperatorUpdated')
          .withArgs(buyer.address, true)
      assert.isTrue(await saleFactory.isOperator(buyer.address))
    })

    it("should revoke the operator", async function () {
      // adding operator&validator role
      await saleFactory.setOperator(buyer.address, true)
      await expect(saleFactory.setOperator(buyer.address, false))
          .emit(saleFactory, 'OperatorUpdated')
          .withArgs(buyer.address, false)

      assert.isFalse(await saleFactory.isOperator(buyer.address))
    })
  })

  describe('#newSale', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()

      const [saleVestingSchedule, msg] = await saleSetupHasher.validateAndPackVestingSteps([
        {
          waitTime: 10,
          percentage: 50
        },
        {
          waitTime: 1000,
          percentage: 100
        }
      ])

      saleSetup = {
        owner: seller.address,
        minAmount: 100,
        capAmount: 20000,
        tokenListTimestamp: 0,
        remainingAmount: 0,
        pricingToken: 1,
        pricingPayment: 2,
        paymentTokenId: 0,
        vestingSteps: saleVestingSchedule[0],
        sellingToken: sellingToken.address,
        totalValue: 50000,
        tokenIsTransferable: true,
        tokenFeePoints: 500,
        extraFeePoints: 0,
        paymentFeePoints: 300,
        saleAddress: addr0
      };
    })

    it("should create a new sale", async function () {

      hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)

      transaction = await saleFactory.connect(operator).approveSale(hash)
      await transaction.wait()
      saleId = await saleFactory.getSaleIdBySetupHash(hash)

      await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address))
          .emit(saleFactory, "NewSale")
      const saleAddress = await saleDB.getSaleAddressById(saleId)
      const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

    })

    it("should throw if trying to create a sale without a pre-approval", async function () {

      let saleId = await saleDB.nextSaleId()

      await assertThrowsMessage(
          saleFactory.newSale(saleId, saleSetup, [], tether.address),
          'SaleFactory: non approved sale or modified params')

    })

    it("should throw if trying to create a sale with a modified setup", async function () {

      hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)

      transaction = await saleFactory.connect(operator).approveSale(hash)
      await transaction.wait()
      saleId = await saleFactory.getSaleIdBySetupHash(hash)

      saleSetup.capAmount = 34500

      await assertThrowsMessage(
          saleFactory.newSale(saleId, saleSetup, [], tether.address),
          'SaleFactory: non approved sale or modified params')
    })
  })
})
