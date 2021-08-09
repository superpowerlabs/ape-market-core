const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {signPackedData, assertThrowsMessage, addr0} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe.skip("SANFT", async function () {

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
    return signPackedData(ethers, saleSetupHasher, 'packAndHashSaleConfiguration', '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', saleId.toNumber(), setup, schedule, tether.address)
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

    let saleId = await saleData.nextSaleId()

    await saleFactory.connect(operator).approveSale(saleId)

    let signature = await getSignatureByValidator(saleId, saleSetup)

    await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address, signature))
        .emit(saleFactory, "NewSale")
    const saleAddress = await saleData.getSaleAddressById(saleId)
    const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
    assert.isTrue(await saleData.getSaleIdByAddress(saleAddress) > 0)


    // seller approves
    await sellingToken.connect(seller).approve(saleAddress, saleSetup.capAmount * 1.05)

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

    it("should verify that the SANFT is correctly set when the buyer invests", async function () {
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
          'SANFTManager: length of sa does not match split'
      )

    })

    it("should throw if trying to split a token keeping more than it owns", async function () {

      let nft = await satoken.tokenOfOwnerByIndex(buyer.address, 0);
      await assertThrowsMessage(
          satoken.connect(buyer).split(nft, [normalize(300)]),
          'SANFTManager: Split is incorrect'
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
      await factory.connect(operator).approveSale(sale2Id)
      let signature = signNewSale(ethers, factory, sale2Id, saleSetup, saleVestingSchedule)
      await factory.connect(seller).newSale(sale2Id, saleSetup, saleVestingSchedule, signature)
      sale2 = new ethers.Contract(saleData.getSaleAddressById(sale2Id), saleJson.abi, ethers.provider)
      sale2Address = await sale2.address

      await sellingToken.connect(seller).approve(sale2Address, saleSetup.capAmount * 1.05)

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
          'SANFT: Only owner can merge tokens'
      )

    })


  })

  // will test the vest function when testing the sales

})
