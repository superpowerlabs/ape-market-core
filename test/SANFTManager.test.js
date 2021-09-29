const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {
  initEthers,
  assertThrowsMessage,
  addr0
} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SANFTManager", async function () {

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
      , sellingToken2
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
      , sale
      , saleAddress2
      , saleId2
      , sale2

  before(async function () {
    [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()
  })

  function normalize(val, n = 18) {
    return '' + val + '0'.repeat(n)
  }

  async function initNetworkAndDeploy(isFutureToken = false, futureTokenSaleId = 0) {


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
      minAmount: 30,
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
      saleAddress: addr0,
      isFutureToken,
      futureTokenSaleId
    };


    hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)

    transaction = await saleFactory.connect(operator).approveSale(hash)

    await transaction.wait()

    saleId = await saleFactory.getSaleIdBySetupHash(hash)

    await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address))
        .emit(saleFactory, "NewSale")
    saleAddress = await saleDB.getSaleAddressById(saleId)
    sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
    assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

    await sellingToken.connect(seller).approve(saleAddress, await saleData.fromValueToTokensAmount(saleId, saleSetup.totalValue * 1.05))
    await sale.connect(seller).launch()

    await tether.connect(buyer).approve(saleAddress, normalize(400, 6));
    await saleData.connect(seller).approveInvestors(saleId, [buyer.address], [normalize(200, 6)])
    await sale.connect(buyer).invest(200)

  }


  describe('#split', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should throw if trying to split a token with inconsistent SAs", async function () {

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      await assertThrowsMessage(
          sANFTManager.connect(buyer).split(nft, [normalize(80), normalize(9)]),
          'SANFTManager: length of SAs does not match split'
      )

    })

    it("should throw if trying to split a token keeping more than it owns", async function () {

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      await assertThrowsMessage(
          sANFTManager.connect(buyer).split(nft, [normalize(300)]),
          'SANFTManager: kept amounts cannot be larger that remaining amounts'
      )

    })

    it("should split if everything is fine", async function () {

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      let bundle = await sANFT.getBundle(nft);
      assert.equal(bundle[0].remainingAmount.toString(), normalize(100))
      await sANFTManager.connect(buyer).split(nft, [normalize(30)])

      nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      let nft2 = await sANFT.tokenOfOwnerByIndex(buyer.address, 1);
      bundle = await sANFT.getBundle(nft);
      let bundle2 = await sANFT.getBundle(nft2);

      assert.equal(bundle[0].remainingAmount.toString(), normalize(30))
      // 69 because buyer payed a 1% fee
      assert.equal(bundle2[0].remainingAmount.toString(), normalize(69))
    })

  })

  describe('#merge', async function () {


    beforeEach(async function () {
      await initNetworkAndDeploy()

      // buyer makes a second investment in sale 1
      await tether.connect(buyer).approve(saleAddress, normalize(50, 6));
      await saleData.connect(seller).approveInvestors(saleId, [buyer.address], [normalize(40, 6)])
      await sale.connect(buyer).invest(40)

      // deploy a new token
      sellingToken2 = await deployUtils.deployContractBy("ERC20Token", seller, "CBA Token", "CBA")

      // adjust the setup
      saleSetup.sellingToken = sellingToken2.address
      saleSetup.totalValue = 100000
      saleSetup.pricingToken = 50
      saleSetup.pricingPayment = saleId

      // setup the second sale

      hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)
      transaction = await saleFactory.connect(operator).approveSale(hash)
      transaction.wait()
      saleId2 = await saleFactory.getSaleIdBySetupHash(hash)



      await saleFactory.connect(seller).newSale(saleId2, saleSetup, [], tether.address)

      saleAddress2 = await saleDB.getSaleAddressById(saleId2)
      sale2 = new ethers.Contract(saleAddress2, saleJson.abi, ethers.provider)

      const allTokensAmount = await saleData.fromValueToTokensAmount(saleId2, saleSetup.totalValue * 1.05)
      assert.equal(allTokensAmount.toString(), '5250000000000000000000000')
      await sellingToken2.connect(seller).approve(saleAddress2, allTokensAmount)
      await sale2.connect(seller).launch()

      // buyer invests in sale 2
      await tether.connect(buyer).approve(saleAddress2, normalize(400, 6));
      await saleData.connect(seller).approveInvestors(saleId2, [buyer.address], [normalize(300, 6)])
      await sale2.connect(buyer).invest(300)

      // buyer2 invests in sale 2
      await tether.connect(buyer2).approve(saleAddress2, normalize(400, 6));
      await saleData.connect(seller).approveInvestors(saleId2, [buyer2.address], [normalize(300, 6)])
      await sale2.connect(buyer2).invest(300)

    })

    it("should merge two tokens", async function () {

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      let nft2 = await sANFT.tokenOfOwnerByIndex(buyer.address, 1)
      let nft3 = await sANFT.tokenOfOwnerByIndex(buyer.address, 2)
      let bundle1 = await sANFT.getBundle(nft);
      let bundle2 = await sANFT.getBundle(nft2);
      let bundle3 = await sANFT.getBundle(nft3);

      let [areMergeable, message] = await sANFTManager.areMergeable([nft, nft2, nft3])
      assert.isTrue(areMergeable)
      assert.equal(message, 'NFTs are mergeable')

      let sumAmountSale1 = bundle1[0].remainingAmount.add(bundle2[0].remainingAmount)
      let fee1 = sumAmountSale1.mul(await sANFTManager.feePoints()).div(10000)

      let sumAmountSale2 = bundle3[0].remainingAmount
      let fee2 = sumAmountSale2.mul(await sANFTManager.feePoints()).div(10000)

      await sANFTManager.connect(buyer).merge([nft, nft2, nft3])

      // new NFT after merge
      let nft4 = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      let bundle4 = await sANFT.getBundle(nft4);

      assert.equal(bundle4[0].remainingAmount.toString(), sumAmountSale1.sub(fee1).toString())
      assert.equal(bundle4[1].remainingAmount.toString(), sumAmountSale2.sub(fee2).toString())

      assert.equal(await sANFT.getBundle(nft).length, undefined)
      assert.equal(await sANFT.getBundle(nft2).length, undefined)
      assert.equal(await sANFT.getBundle(nft3).length, undefined)

      assertThrowsMessage(
          sANFT.ownerOf(nft),
          'ERC721: owner query for nonexistent token'
      )
      assertThrowsMessage(
          sANFT.ownerOf(nft2),
          'ERC721: owner query for nonexistent token'
      )
      assertThrowsMessage(
          sANFT.ownerOf(nft3),
          'ERC721: owner query for nonexistent token'
      )

    })

    it("should throw if trying to merge tokens owned by different owners", async function () {

      let nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
      let nft2 = await sANFT.tokenOfOwnerByIndex(buyer2.address, 0)

      let [areMergeable, message] = await sANFTManager.areMergeable([nft, nft2])
      assert.isFalse(areMergeable)
      assert.equal(message, 'All NFTs must be owned by same owner')

      await assertThrowsMessage(
          sANFTManager.connect(buyer).merge([nft, nft2]),
          'SANFTManager: All NFTs must be owned by same owner'
      )

    })
  })

  describe.only('#swap', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy(true)
    })

    it('should swap from the coupon to the final token', async function() {
      // buyer makes a second investment in sale 1

      let tokenId = await sANFT.tokenOfOwnerByIndex(buyer.address, 0)
      let bundle = await sANFT.getBundle(tokenId)
      assert.equal(bundle[0].saleId, saleId)

      // deploy a new token
      sellingToken2 = await deployUtils.deployContractBy("ERC20Token", seller, "CBA Token", "CBA")

      // adjust the setup
      saleSetup.sellingToken = sellingToken2.address
      saleSetup.isFutureToken = false
      saleSetup.futureTokenSaleId = 1

      // setup the second sale

      hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)
      transaction = await saleFactory.connect(operator).approveSale(hash)
      transaction.wait()
      saleId2 = await saleFactory.getSaleIdBySetupHash(hash)
      await saleFactory.connect(seller).newSale(saleId2, saleSetup, [], tether.address)

      saleAddress2 = await saleDB.getSaleAddressById(saleId2)
      sale2 = new ethers.Contract(saleAddress2, saleJson.abi, ethers.provider)
      await sellingToken2.connect(seller).approve(saleAddress2, await saleData.fromValueToTokensAmount(saleId2, saleSetup.totalValue * 1.05))
      await sale2.connect(seller).launch()

      await sANFTManager.connect(buyer).swap(tokenId, saleId2)

      let tokenId2 = await sANFT.tokenOfOwnerByIndex(buyer.address, 0)
      let bundle1 = await sANFT.getBundle(tokenId2)
      assert.equal(bundle1[0].saleId, saleId2)

    })

  })

})
