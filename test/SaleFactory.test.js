const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {signPackedData, assertThrowsMessage, addr0} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SaleFactory", async function () {

  const deployUtils = new DeployUtils(ethers)

  let apeRegistry
      , profile
      , saleSetupHasher
      , saleData
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

  async function getSignatureByValidator(saleId, setup, schedule = []) {
    return signPackedData( saleSetupHasher, 'packAndHashSaleConfiguration', '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', saleId.toNumber(), setup, schedule, tether.address)
  }

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
      validators: [validator.address],
      operators: [operator.address]
    })

    apeRegistry = results.apeRegistry
    profile = results.profile
    saleSetupHasher = results.saleSetupHasher
    saleData = results.saleData
    saleFactory = results.saleFactory
    sANFT = results.sANFT
    sANFTManager = results.sANFTManager
    tokenRegistry = results.tokenRegistry

    sellingToken = await deployUtils.deployContract("ERC20Token", "Abc Token", "ABC")
    tether = await deployUtils.deployContract("TetherMock")

    await (await tether.transfer(buyer.address, normalize(40000))).wait()
    await (await tether.transfer(buyer2.address, normalize(50000))).wait()

  }

  describe('#constructor & #updateFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the apeFactory is correctly set", async function () {
      assert.isTrue(await saleFactory.isOperator(operator.address))
      assert.isTrue(await saleFactory.isValidator(validator.address))
    })

  })

  describe('#newSale', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()

      const [saleVestingSchedule, msg] = await saleData.validateAndPackVestingSteps([
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
        tokenFeePercentage: 5,
        extraFeePercentage: 0,
        paymentFeePercentage: 3,
        softCapPercentage: 0,
        saleAddress: addr0
      };

    })

    it("should create a new sale", async function () {

      let saleId = await saleData.nextSaleId()

      await saleFactory.connect(operator).approveSale(saleId)

      let signature = await getSignatureByValidator(saleId, saleSetup)

      await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address, signature))
          .emit(saleFactory, "NewSale")
      const saleAddress = await saleData.getSaleAddressById(saleId)
      const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      assert.isTrue(await saleData.getSaleIdByAddress(saleAddress) > 0)

    })

    it("should throw if trying to create a sale without a pre-approval", async function () {

      let saleId = await saleData.nextSaleId()
      let signature = await getSignatureByValidator(saleId, saleSetup)

      await assertThrowsMessage(
          saleFactory.newSale(saleId, saleSetup, [], tether.address, signature),
          'SaleData: invalid id')

    })

    it("should throw if trying to create a sale with a modified setup", async function () {

      let saleId = await saleData.nextSaleId()

      let signature = await getSignatureByValidator(saleId, saleSetup)

      await saleFactory.connect(operator).approveSale(saleId)

      saleSetup.capAmount = 34500

      await assertThrowsMessage(
          saleFactory.newSale(saleId, saleSetup, [], tether.address, signature),
          'SaleFactory: invalid signature or modified params')

    })


  })

})
