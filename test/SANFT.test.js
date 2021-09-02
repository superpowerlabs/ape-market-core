const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {
  initEthers,
  assertThrowsMessage,
  addr0,
  getTimestamp,
  increaseBlockTimestampBy,
  formatBundle
} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SANFT", async function () {

  const deployUtils = new DeployUtils(ethers)
  initEthers(ethers)

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
      , saleVestingSchedule
      , owner
      , validator
      , operator
      , apeWallet
      , seller
      , buyer
      , buyer2
      , saleAddress
      , saleId

  before(async function () {
    [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()
  })

  function normalize(val, n = 18) {
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
    saleDB = results.saleDB
    saleFactory = results.saleFactory
    sANFT = results.sANFT
    sANFTManager = results.sANFTManager
    tokenRegistry = results.tokenRegistry
    tether = results.USDT

    sellingToken = await deployUtils.deployContractBy("ERC20Token", seller, "Abc Token", "ABC")

    await (await tether.transfer(buyer.address, normalize(40000, 6))).wait()
    await (await tether.transfer(buyer2.address, normalize(50000, 6))).wait()

    saleVestingSchedule = [
      {
        waitTime: 0,
        percentage: 20
      },
      {
        waitTime: 30,
        percentage: 50
      },
      {
        waitTime: 90,
        percentage: 100
      }
    ]

    const [schedule, msg] = await saleSetupHasher.validateAndPackVestingSteps(saleVestingSchedule)

    saleSetup = {
      owner: seller.address,
      minAmount: 100,
      capAmount: 20000,
      tokenListTimestamp: 0,
      remainingAmount: 0,
      pricingToken: 1,
      pricingPayment: 2,
      paymentTokenId: 0,
      vestingSteps: schedule[0],
      sellingToken: sellingToken.address,
      totalValue: 50000,
      tokenIsTransferable: true,
      tokenFeePoints: 500,
      extraFeePoints: 0,
      paymentFeePoints: 300,
      saleAddress: addr0
    };

    hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)
    transaction = await saleFactory.connect(operator).approveSale(hash)
    transaction.wait()
    saleId = await saleFactory.getSaleIdBySetupHash(hash)

    await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address))
        .emit(saleFactory, "NewSale")
    saleAddress = await saleDB.getSaleAddressById(saleId)
    const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
    assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

    await sellingToken.connect(seller).approve(saleAddress, await saleData.fromValueToTokensAmount(saleId, saleSetup.totalValue * 1.05))
    await sale.connect(seller).launch()

    await tether.connect(buyer).approve(saleAddress, normalize(400, 6));
    await saleData.connect(seller).approveInvestor(saleId, buyer.address, normalize(200, 6))
    await sale.connect(buyer).invest(200)

  }


  describe('#constructor', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the SANFT is correctly set when the buyer invests", async function () {
      let tokenId = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      assert.equal(tokenId, 1);
    })

  })

  describe('#withdraw', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should throw if trying to withdraw an unlisted token", async function () {

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      await expect(sANFT.connect(buyer).withdraw(nft, [100])).revertedWith('SANFTManager: Cannot withdraw not available tokens')

    })

    it("should withdraw based on vesting period after token listing", async function () {

      await saleData.connect(seller).triggerTokenListing(saleId)
      let vestedPercentage = await saleData.vestedPercentage(saleId)
      expect(vestedPercentage).equal(20)

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      let expected = await saleData.fromValueToTokensAmount(saleId, (200 * saleVestingSchedule[0].percentage) / 100)
      let bundle = await sANFT.getBundle(nft)
      let [saleIds, withdrawables] = await sANFT.withdrawables(nft)

      assert.equal(withdrawables[0].toString(), expected.toString())

      expect(await sellingToken.balanceOf(buyer.address)).equal(0)
      await sANFT.connect(buyer).withdraw(nft, [expected])

      let nft2 = await sANFT.tokenOfOwnerByIndex(buyer.address, 0)
      assert.notEqual(nft.toNumber(), nft2.toNumber())
      let bundle2 = await sANFT.getBundle(nft2)

      expect(bundle[0].remainingAmount).equal(bundle2[0].remainingAmount.add(expected))
      expect(await sellingToken.balanceOf(buyer.address)).equal(expected);

      await increaseBlockTimestampBy(31 * 24 * 3600)

      vestedPercentage = await saleData.vestedPercentage(saleId)
      expect(vestedPercentage).equal(50)

      expected = 200 * (saleVestingSchedule[1].percentage - saleVestingSchedule[0].percentage) / 100

      assert.equal((await sANFT.withdrawables(nft2))[1][0].toString(), (await saleData.fromValueToTokensAmount(saleId, expected)).toString())

    })

  })

})
