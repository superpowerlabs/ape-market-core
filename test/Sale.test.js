const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

// const delay = ms => new Promise(res => setTimeout(res, ms));

const saleJson = require('../src/artifacts/contracts/sale/Sale.sol/Sale.json')

describe.only("Sale", function() {


  let ERC20Token
  let abcToken
  let xyzToken
  let Tether
  let tether
  let SAStorage
  let storage
  let SAToken
  let satoken
  let SaleFactory
  let factory

  let saleSetup
  let saleVestingSchedule

  let owner, factoryAdmin, apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, factoryAdmin, apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2] = await ethers.getSigners()
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
    factory.grantLevel(await factory.FACTORY_ADMIN_LEVEL(), factoryAdmin.address)

    SAToken = await ethers.getContractFactory("SAToken")
    satoken = await SAToken.deploy(factory.address, storage.address)
    await satoken.deployed()

    ERC20Token = await ethers.getContractFactory("ERC20Token")
    abcToken = await ERC20Token.connect(abcOwner).deploy("Abc Token", "ABC")
    await abcToken.deployed()
    xyzToken = await ERC20Token.connect(xyzOwner).deploy("XYZ", "XYZ");
    await xyzToken.deployed();

    Tether = await ethers.getContractFactory("TetherMock")
    tether = await Tether.connect(tetherOwner).deploy()
    await tether.deployed()
    await (await tether.connect(tetherOwner).transfer(investor1.address, 40000))
    await (await tether.connect(tetherOwner).transfer(investor2.address, 50000))

    saleSetup = {
      satoken: satoken.address,
      minAmount: 100,
      capAmount: 20000,
      remainingAmount: 0,
      pricingToken: 1,
      pricingPayment: 2,
      sellingToken: abcToken.address,
      paymentToken: tether.address,
      owner: abcOwner.address,
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

    await factory.connect(factoryAdmin).newSale(saleSetup,saleVestingSchedule)


  }

  describe('#verify initialization', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the Sale is deployed correctly", async function () {

      const saleAddress = await factory.lastSale()
      const sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      expect(await sale.levels(saleSetup.owner)).to.equal(await sale.SALE_OWNER_LEVEL())

    })


    it("should verify that the investors are funded", async function () {

      expect(await tether.balanceOf(investor1.address)).to.equal(40000);
      expect(await tether.balanceOf(investor2.address)).to.equal(50000);

    })

  })


})