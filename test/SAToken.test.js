const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("SAToken", async function () {

  let SAToken
  let token

  let owner, manager, sale, apeFactory, newFactory
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, manager, sale, apeFactory, newFactory] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {
    SAToken = await ethers.getContractFactory("SAToken")
    token = await SAToken.deploy(apeFactory.address)
    await token.deployed()
    await token.setManager(manager.address)
  }

  describe('#constructor & #updateFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the apeFactory is correctly set", async function () {
      assert.equal((await token.factory()), apeFactory.address)
    })

    it("should verify that apeFactory is not the owner if specified", async function () {
      await token.updateFactory(newFactory.address)
      assert.equal((await token.factory()), newFactory.address)
    })


  })

  // describe('#mint', async function () {
  //
  //   beforeEach(async function () {
  //     await initNetworkAndDeploy()
  //   })
  //
  //   it("should mint a token if a sale does it", async function () {
  //
  //     await expect(operator.connect(manager).addBundle(saId, sale.address, 0, 100))
  //         .to.emit(operator, 'BundleAdded')
  //         .withArgs(saId, sale.address, 0, 100)
  //     assert.equal((await operator.getBundle(saId)).sas[0].sale, sale.address)
  //   })
  //
  //   it("should throw adding again the same sale id", async function () {
  //
  //     let saId = 3
  //
  //     await operator.connect(manager).addBundle(saId, sale.address, 0, 100)
  //
  //     await assertThrowsMessage(
  //         operator.connect(manager).addBundle(saId, sale.address, 20, 20),
  //         'SAToken: Bundle already added')
  //
  //   })
  // })

})
