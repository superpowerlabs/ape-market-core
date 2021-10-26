const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {signPackedData, assertThrowsMessage, addr0} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

// This test has been run against BSC Testnet with
// it.only("should launch a sale" . . .

describe("Sale", async function () {

  const deployUtils = new DeployUtils(ethers)

  process.env.VERBOSE_LOG = true

  let apeRegistry
      , profile
      , saleSetupHasher
      , saleData
      , saleDB
      , saleId
      , saleFactory
      , sale
      , saleAddress
      , sANFT
      , sANFTManager
      , tokenRegistry
      , sellingToken
      , tether
      , saleSetup
      , owner
      , operator
      , apeWallet
      , seller


  before(async function () {
    [owner, apeWallet, operator, seller] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  function normalize(val, n = 6 /* tether */) {
    return '' + val + '0'.repeat(n)
  }

  async function initNetworkAndDeploy() {

    sellingToken = await deployUtils.deployContractBy("ERC20Token", seller, "Abc Token", "ABC")

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
    tether = results.uSDT

    const saleVestingSchedule = await saleSetupHasher.validateAndPackVestingSteps([
      {
        waitTime: 10,
        percentage: 50
      },
      {
        waitTime: 999,
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
      saleAddress: addr0,
      isFutureToken: false,
      futureTokenSaleId: 0,
      tokenFeeInvestorPoints: 100
    };


    hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)
    transaction = await saleFactory.connect(operator).approveSale(hash)
    await transaction.wait()
    saleId = await saleFactory.getSaleIdBySetupHash(hash)
    await saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address)
    saleAddress = await saleDB.getSaleAddressById(saleId)
    console.log('saleAddress', saleAddress)
    sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)

  }

  describe('#newSale', async function () {

    this.timeout(500000)

    beforeEach(async function () {
      // console.log('Init')
      await initNetworkAndDeploy()
    })

    it("should launch a sale", async function () {

// console.log('Launch')

      const [amount, fee] = await saleData.getTokensAmountAndFeeByValue(saleId, saleSetup.totalValue)

      await sellingToken.connect(seller).approve(saleAddress, amount.add(fee))

      await expect(sale.connect(seller).launch({
        gasLimit: 400000
      }))
          .emit(saleData, 'SaleLaunched')
          .withArgs(saleId, saleSetup.totalValue, amount);

      expect(await sellingToken.balanceOf(sale.address)).equal(amount.add(fee));

    })

    it("should extend an existing sale", async function () {

      let [amount, fee] = await saleData.getTokensAmountAndFeeByValue(saleId, saleSetup.totalValue)

      await sellingToken.connect(seller).approve(saleAddress, amount.add(fee))

      await sale.connect(seller).launch()

      // seller adds a 30% to the sale
      const extraValue = saleSetup.totalValue * 0.3;

      let [extraAmount, extraFee] = await saleData.getTokensAmountAndFeeByValue(saleId, extraValue)

      await sellingToken.connect(seller).approve(saleAddress, extraAmount.add(extraFee))

      await expect(sale.connect(seller).extend(extraValue))
          .emit(saleData, 'SaleExtended')
          .withArgs(saleId, extraValue, extraAmount);

      expect(await sellingToken.balanceOf(sale.address)).equal(amount.add(fee).add(extraAmount).add(extraFee))
    })
  })
})
