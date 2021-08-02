const {expect, assert} = require("chai")
const {assertThrowsMessage, signNewSale, getTimestamp} = require('./helpers')
const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe.only("SAToken", async function () {

  let Profile
  let profile
  let ERC20Token
  let sellingToken
  let Tether
  let tether
  let SAToken
  let satoken
  let SaleFactory
  let factory
  let SaleData
  let saleData
  let SATokenExtras
  let tokenExtras
  let sale
  let saleId

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

  function normalize(amount) {
    return '' + parseInt(amount) + '0'.repeat(18);
  }

  function normalizeMinMaxAmount(amount) {
    return '' + parseInt(amount) + '0'.repeat(15);
  }

  async function initNetworkAndDeploy() {

    Profile = await ethers.getContractFactory("Profile")
    profile = await Profile.deploy()
    await profile.deployed()

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
    satoken = await SAToken.deploy(saleData.address, factory.address, tokenExtras.address)
    await satoken.deployed()

    await tokenExtras.setToken(satoken.address)


    ERC20Token = await ethers.getContractFactory("ERC20Token")
    sellingToken = await ERC20Token.connect(seller).deploy("Abc Token", "ABC")
    await sellingToken.deployed()

    Tether = await ethers.getContractFactory("TetherMock")
    tether = await Tether.deploy()
    await tether.deployed()
    await (await tether.transfer(buyer.address, normalize(40000))).wait()
    await (await tether.transfer(buyer2.address, normalize(50000))).wait()

    const saleSetup = {
      satoken: satoken.address,
      minAmount: 100000,
      capAmount: 20000000,
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

    saleId = await saleData.nextSaleId()
    await factory.connect(factoryAdmin).approveSale(saleId)
    let signature = signNewSale(ethers, factory, saleId, saleSetup, saleVestingSchedule)
    await factory.connect(seller).newSale(saleId, saleSetup, saleVestingSchedule, signature)

    sale = new ethers.Contract(saleData.getSaleAddressById(saleId), saleJson.abi, ethers.provider)

    await sellingToken.connect(seller).approve(sale.address, normalizeMinMaxAmount(saleSetup.capAmount * 1.05))

    await sale.connect(seller).launch()

    await tether.connect(buyer).approve(sale.address, normalize(200 * 2 * 1.1));
    await saleData.connect(seller).approveInvestor(saleId, buyer.address, normalize(200))
    await sale.connect(buyer).invest(normalize(200))

  }


  describe('#constructor', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the SAToken is correctly set when the buyer invests", async function () {
      let tokenId = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      assert.equal(tokenId, 0);
    })

  })

  describe('#vest', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it.only("should vest a token", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 20]);
      await satoken.connect(buyer).vest(nft);
      nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let bundle = await satoken.getBundle(nft);
      console.log(bundle[0])
      assert.equal(bundle[0].sale, sale.address)
      assert.equal(bundle[0].vestedPercentage, 10)
      expect(await sellingToken.balanceOf(buyer.address)).equal(normalize(5000));
      expect(bundle[0].remainingAmount).equal(normalize(5000));

    })

    it("should throw if a not legit sale try to mint a token", async function () {

      await assertThrowsMessage(
          fakeSale.mintToken(buyer.address, 100),
          'SAToken: Only legit sales can mint its own NFT!')

    })

    it("should throw if a non-contract try to mint a token as Sale", async function () {

      await assertThrowsMessage(
          satoken.connect(buyer2).mint(buyer.address, addr0, 100, 0),
          'SAToken: Only legit sales can mint its own NFT!')

    })

    it("should throw if a non-manager try to mint a token as SATokenExtras", async function () {

      await assertThrowsMessage(
          satoken.connect(buyer2).mint(buyer.address, buyer.address, 100, 0),
          'SAToken: Only SATokenExtras can mint tokens for an existing sale')

    })
  })

  // will test the vest function when testing the sales

})
