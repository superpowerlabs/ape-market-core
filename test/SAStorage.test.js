const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("SAStorage", async function () {

  let Profile
  let profile
  let SAStorage
  let storage
  let MANAGER_LEVEL

  let owner, manager, newManager, sale1, sale2, sale3, sale4
  let addr0 = '0x0000000000000000000000000000000000000000'

  before(async function () {
    [owner, manager, newManager, sale1, sale2, sale3, sale4] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {
    SAStorage = await ethers.getContractFactory("SAStorage")
    storage = await SAStorage.deploy()
    await storage.deployed()
    MANAGER_LEVEL = await storage.MANAGER_LEVEL()
    // console.log(MANAGER_LEVEL.toNumber())
    await storage.grantLevel(MANAGER_LEVEL, manager.address)
  }

  async function prePopulate() {
    let saId = 0
    await storage.connect(manager).newBundleWithSA(saId++, sale1.address, 0, 100)
    await storage.connect(manager).newBundleWithSA(saId++, sale2.address, 0, 100)
    await storage.connect(manager).newBundleWithSA(saId++, sale1.address, 10, 90)
    await storage.connect(manager).newBundleWithSA(saId++, sale2.address, 30, 50)
  }

  describe('#constructor & #getManager', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the manager is correctly set", async function () {
      assert.equal((await storage.levels(manager.address)).toNumber(), MANAGER_LEVEL)
    })

  })

  describe('#setManager', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should update the manager", async function () {
      await expect(storage.grantLevel(MANAGER_LEVEL, newManager.address))
          .emit(storage, 'LevelSet')
          .withArgs(MANAGER_LEVEL, newManager.address, owner.address)
      assert.equal((await storage.levels(newManager.address)).toNumber(), MANAGER_LEVEL)
    })

  })

  describe('#newBundleWithSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should add new sale to the _sas", async function () {

      let saId = 3

      await expect(storage.connect(manager).newBundleWithSA(saId, sale1.address, 0, 100))
          .emit(storage, 'BundleAdded')
          .withArgs(saId, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
    })

    it("should throw adding again the same sale id", async function () {

      let saId = 3

      await storage.connect(manager).newBundleWithSA(saId, sale1.address, 0, 100)

      await assertThrowsMessage(
          storage.connect(manager).newBundleWithSA(saId, sale1.address, 20, 20),
          'SAStorage: Bundle already added')

    })
  })

  describe('#deleteBundle', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should delete a sale", async function () {

      let saId = 3
      await storage.connect(manager).newBundleWithSA(saId, sale1.address, 0, 100)
      await expect(storage.connect(manager).deleteBundle(saId))
          .emit(storage, 'BundleDeleted')
          .withArgs(saId)
      assert.isUndefined((await storage.getBundle(saId)).sas[0])
    })

    it("should throw deleting a not existing sa", async function () {

      let saId = 3

      await assertThrowsMessage(
          storage.connect(manager).deleteBundle(saId),
          'SAStorage: Bundle does not exist')

    })

  })

  describe('#addSAToBundle', async function () {

    let newSA

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
      newSA = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }
    })

    it("should add an array of SAs", async function () {

      let saId = 2

      await storage.connect(manager).addSAToBundle(saId, newSA)
      assert.equal((await storage.getBundle(saId)).sas.length, 2)
      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[1].sale, sale3.address)
    })

    it("should throw adding a SA to a not existing sa", async function () {

      await assertThrowsMessage(
          storage.connect(manager).addSAToBundle(20, newSA),
          'SAStorage: Bundle does not exist')

    })


  })

})
