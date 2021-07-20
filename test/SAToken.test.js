const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("SAToken", async function () {

  let SAStorage
  let storage
  let SAToken
  let token
  let SaleMock
  let saleMock
  let fakeSale
  let FactoryMock
  let factoryMock
  let PAUSER_ROLE

  let owner, manager, sale, apeFactory, newFactory, buyer, buyer2
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, manager, sale, apeFactory, newFactory, fakeSale, buyer, buyer2] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {
    SAStorage = await ethers.getContractFactory("SAStorage")
    storage = await SAStorage.deploy()
    await storage.deployed()
    SaleMock = await ethers.getContractFactory("SaleMock")
    saleMock = await SaleMock.deploy()
    await saleMock.deployed()
    fakeSale = await SaleMock.deploy()
    await fakeSale.deployed()
    FactoryMock = await ethers.getContractFactory("FactoryMock")
    factoryMock = await FactoryMock.deploy()
    await factoryMock.deployed()
    await factoryMock.setLegitSale(saleMock.address)
    SAToken = await ethers.getContractFactory("SAToken")
    token = await SAToken.deploy(factoryMock.address, storage.address)
    await token.deployed()
    await saleMock.setToken(token.address)
    await fakeSale.setToken(token.address)
    await storage.grantRole(await storage.MANAGER_ROLE(), token.address)
    await token.grantRole(await token.PAUSER_ROLE(), manager.address)
  }

  describe('#constructor & #updateFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the apeFactory is correctly set", async function () {
      assert.equal((await token.factory()), factoryMock.address)
    })

    it("should set and verify that newFactory is the new factory", async function () {
      await token.updateFactory(newFactory.address)
      assert.equal((await token.factory()), newFactory.address)
    })

  })

  describe('#mint', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should allow saleMock to mint a token ", async function () {

      await expect(saleMock.mintToken(buyer.address, 100))
          .to.emit(token, 'Transfer')
          .withArgs(addr0, buyer.address, 0)
      assert.equal(await token.ownerOf(0), buyer.address)

      await expect(saleMock.mintToken(buyer2.address, 50))
          .to.emit(token, 'Transfer')
          .withArgs(addr0, buyer2.address, 1)
      assert.equal(await token.ownerOf(1), buyer2.address)
    })

    it("should throw if a not legit sale try to mint a token", async function () {

      await assertThrowsMessage(
          fakeSale.mintToken(buyer.address, 100),
          'SAToken: Only legit sales can mint its own NFT!')

    })

    it("should throw if a non-contract try to mint a token", async function () {

      await assertThrowsMessage(
          token.connect(buyer2).mint(buyer.address, 100),
          'SAToken: The caller is not a contract')

    })
  })

})
