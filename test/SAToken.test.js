const {expect, assert} = require("chai")
const {assertThrowsMessage, signNewSale, getTimestamp} = require('./helpers')
const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("SAToken", async function () {

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
  let saleAddress
  let sale2
  let sale2Id
  let sale2Address
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

    await satoken.setupUpPayments(tether.address, 1, apeWallet.address)

    saleSetup = {
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
    saleVestingSchedule = [
      {
        timestamp: 10,
        percentage: 50
      },
      {
        timestamp: 1000,
        percentage: 100
      }]

    // create sale1

    saleId = await saleData.nextSaleId()
    await factory.connect(factoryAdmin).approveSale(saleId)
    let signature = signNewSale(ethers, factory, saleId, saleSetup, saleVestingSchedule)
    await factory.connect(seller).newSale(saleId, saleSetup, saleVestingSchedule, signature)

    sale = new ethers.Contract(saleData.getSaleAddressById(saleId), saleJson.abi, ethers.provider)
    saleAddress = await sale.address

    // seller approves
    await sellingToken.connect(seller).approve(saleAddress, normalizeMinMaxAmount(saleSetup.capAmount * 1.05))

    // launch
    await sale.connect(seller).launch()

    await tether.connect(buyer).approve(saleAddress, normalize(3000));
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

    it("should throw if trying to vest an unlisted token", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let bundle = await satoken.getBundle(nft);
      await expect(satoken.connect(buyer).vest(nft)).revertedWith('SaleData: token has not been listed yet')

    })

    it("should not vest if vesting period not passed", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let bundle = await satoken.getBundle(nft);
      await expect(satoken.connect(buyer).vest(nft)).revertedWith('SaleData: token has not been listed yet')
      nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      bundle = await satoken.getBundle(nft);

      assert.equal(bundle[0].sale, saleAddress)
      assert.equal(bundle[0].vestedPercentage.toNumber(), 0)
      expect(await sellingToken.balanceOf(buyer.address)).equal(0);

    })

    it.skip("should vest a token", async function () {

      await saleData.connect(seller).triggerTokenListing(saleId);

      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 10]);

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await satoken.connect(buyer).vest(nft);
      let bundle = await satoken.getBundle(nft);
      assert.equal(bundle[0].sale, saleAddress)
      assert.equal(bundle[0].vestedPercentage.toNumber(), 0)
      expect(await sellingToken.balanceOf(buyer.address)).equal(normalize(100));

      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 2000]);

      await satoken.connect(buyer).vest(nft);
      let nft2 = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await expect(nft2).equal(nft + 1)
      bundle = await satoken.getBundle(nft2);
      assert.equal(bundle[0].sale, saleAddress)
      assert.equal(bundle[0].vestedPercentage.toNumber(), 50)
      expect(await sellingToken.balanceOf(buyer.address)).equal(normalize(200));

    })

  })

  describe('#split', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await saleData.connect(seller).triggerTokenListing(saleId);
      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 10]);
      await satoken.connect(buyer).vest(nft);
      let bundle = await satoken.getBundle(nft);
      assert.equal(bundle[0].remainingAmount.toString(), normalize(200))
      await tether.connect(buyer).approve(satoken.address, normalize(10))
    })

    it("should throw if trying to split a token like if there are two", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await assertThrowsMessage(
          satoken.connect(buyer).split(nft, [normalize(80), normalize(9)]),
          'SATokenExtras: length of sa does not match split'
      )

    })

    it("should throw if trying to split a token keeping more than it owns", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await assertThrowsMessage(
          satoken.connect(buyer).split(nft, [normalize(300)]),
          'SATokenExtras: Split is incorrect'
      )

    })

    it.skip("should split if everything is fine", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let bundle = await satoken.getBundle(nft);
      await satoken.connect(buyer).split(nft, [normalize(30)])
      nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let nft2 = await satoken.tokenOfOwnerByIndex(buyer.address, 1);
      bundle = await satoken.getBundle(nft);
      let bundle2 = await satoken.getBundle(nft2);
      assert.equal(bundle[0].remainingAmount.toString(), normalize(30))
      assert.equal(bundle2[0].remainingAmount.toString(), normalize(170))

    })

  })

  describe('#merge', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()


      // create sale2
      saleSetup.pricingPayment = 1
      saleSetup.minAmount = 1000

      sale2Id = await saleData.nextSaleId()
      await factory.connect(factoryAdmin).approveSale(sale2Id)
      let signature = signNewSale(ethers, factory, sale2Id, saleSetup, saleVestingSchedule)
      await factory.connect(seller).newSale(sale2Id, saleSetup, saleVestingSchedule, signature)
      sale2 = new ethers.Contract(saleData.getSaleAddressById(sale2Id), saleJson.abi, ethers.provider)
      sale2Address = await sale2.address

      await sellingToken.connect(seller).approve(sale2Address, normalizeMinMaxAmount(saleSetup.capAmount * 1.05))

      await sale2.connect(seller).launch()

      await saleData.connect(seller).approveInvestor(saleId, buyer.address, normalize(130))
      await sale.connect(buyer).invest(normalize(130))

      await tether.connect(buyer).approve(sale2Address, normalize(2000));
      await saleData.connect(seller).approveInvestor(sale2Id, buyer.address, normalize(200))
      await sale2.connect(buyer).invest(normalize(200))

      await tether.connect(buyer2).approve(saleAddress, normalize(2000));
      await saleData.connect(seller).approveInvestor(saleId, buyer2.address, normalize(100))
      await sale.connect(buyer2).invest(normalize(100))

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await saleData.connect(seller).triggerTokenListing(saleId);
      await saleData.connect(seller).triggerTokenListing(sale2Id);

      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 10]);

      await tether.connect(buyer).approve(satoken.address, normalize(500))
      await tether.connect(buyer2).approve(satoken.address, normalize(500))
    })

    it("should merge two tokens", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let nft2 = await satoken.tokenOfOwnerByIndex(buyer.address, 1)
      let bundle1 = await satoken.getBundle(nft);
      let bundle2 = await satoken.getBundle(nft2);

      let areMergeable = await satoken.connect(buyer).areMergeable([nft, nft2])
      assert.equal(areMergeable, 'SUCCESS: Tokens are mergeable')

      await satoken.connect(buyer).merge([nft, nft2])
      let nft3 = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let nft4 = await satoken.tokenOfOwnerByIndex(buyer.address, 1);

      let bundle3 = await satoken.getBundle(nft3);
      let bundle4 = await satoken.getBundle(nft4);

      assert.notEqual(bundle3[0].sale, bundle4[0].sale)

      assert.equal(bundle4[0].remainingAmount.toString(), bundle1[0].remainingAmount.add(bundle2[0].remainingAmount).toString())
    })

    it("should merge three tokens, from two different sales", async function () {

      let nft0 = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let nft1 = await satoken.tokenOfOwnerByIndex(buyer.address, 1)
      let nft2 = await satoken.tokenOfOwnerByIndex(buyer.address, 2)
      let bundle0 = await satoken.getBundle(nft0);
      let bundle1 = await satoken.getBundle(nft1);
      let bundle2 = await satoken.getBundle(nft2);

      let areMergeable = await satoken.connect(buyer).areMergeable([nft0, nft1, nft2])
      assert.equal(areMergeable, 'SUCCESS: Tokens are mergeable')

      await satoken.connect(buyer).merge([nft0, nft1, nft2])
      let nft3 = await satoken.tokenOfOwnerByIndex(buyer.address, 0);

      let bundle3 = await satoken.getBundle(nft3);
      assert.equal(bundle3.length, 2);
      // console.log([nft, ra1, nft2, ra2, nft3, ra4].map(e => e.toString()))

      assert.equal(bundle3[0].remainingAmount.toString(), bundle0[0].remainingAmount.add(bundle1[0].remainingAmount).toString())
      assert.equal(bundle3[1].remainingAmount.toString(), bundle2[0].remainingAmount)
    })

    it("should throw if trying to merge tokens owned by different owners", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      let nft2 = await satoken.tokenOfOwnerByIndex(buyer2.address, 0)

      let areMergeable = await satoken.connect(buyer).areMergeable([nft, nft2])
      assert.equal(areMergeable, 'ERROR 2: All tokens must be owned by msg.sender')

      await assertThrowsMessage(
          satoken.connect(buyer).merge([nft, nft2]),
          'SAToken: Only owner can merge tokens'
      )

    })



  })

  // will test the vest function when testing the sales

})
