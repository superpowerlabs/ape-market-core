const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("SAStorage", async function () {

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
    await storage.connect(manager).addBundleWithSA(saId++, sale1.address, 0, 100)
    await storage.connect(manager).addBundleWithSA(saId++, sale2.address, 0, 100)
    await storage.connect(manager).addBundleWithSA(saId++, sale1.address, 10, 90)
    await storage.connect(manager).addBundleWithSA(saId++, sale2.address, 30, 50)
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
          .to.emit(storage, 'LevelSet')
          .withArgs(MANAGER_LEVEL, newManager.address, owner.address)
      assert.equal((await storage.levels(newManager.address)).toNumber(), MANAGER_LEVEL)
    })

  })

  describe('#addBundleWithSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should add new sale to the _sas", async function () {

      let saId = 3

      await expect(storage.connect(manager).addBundleWithSA(saId, sale1.address, 0, 100))
          .to.emit(storage, 'BundleAdded')
          .withArgs(saId, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
    })

    it("should throw adding again the same sale id", async function () {

      let saId = 3

      await storage.connect(manager).addBundleWithSA(saId, sale1.address, 0, 100)

      await assertThrowsMessage(
          storage.connect(manager).addBundleWithSA(saId, sale1.address, 20, 20),
          'SAStorage: Bundle already added')

    })
  })

  describe('#deleteBundle', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should delete a sale", async function () {

      let saId = 3
      await storage.connect(manager).addBundleWithSA(saId, sale1.address, 0, 100)
      await expect(storage.connect(manager).deleteBundle(saId))
          .to.emit(storage, 'BundleDeleted')
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

  describe('#addNewSAs', async function () {

    let newSAs

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should add an array of SAs", async function () {

      let saId = 2
      newSAs = [
        {
          sale: sale3.address,
          remainingAmount: 100,
          vestedPercentage: 0
        },
        {
          sale: sale4.address,
          remainingAmount: 40,
          vestedPercentage: 30
        }
      ]
      await storage.connect(manager).addNewSAs(saId, newSAs)
      assert.equal((await storage.getBundle(saId)).sas.length, 3)
      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[1].sale, sale3.address)
      assert.equal((await storage.getBundle(saId)).sas[2].sale, sale4.address)
    })

    it("should add an array of sales with just one SA", async function () {

      let saId = 2
      newSAs = [
        {
          sale: sale3.address,
          remainingAmount: 100,
          vestedPercentage: 0
        }
      ]
      await storage.connect(manager).addNewSAs(saId, newSAs)
      assert.equal((await storage.getBundle(saId)).sas.length, 2)
      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[1].sale, sale3.address)
    })

    it("should throw adding an array of SAs to a not existing sa", async function () {

      await assertThrowsMessage(
          storage.connect(manager).addNewSAs(20, newSAs),
          'SAStorage: Bundle does not exist')

    })


  })

  describe('#addNewSA', async function () {

    let newSAs

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

      await storage.connect(manager).addNewSA(saId, newSA)
      assert.equal((await storage.getBundle(saId)).sas.length, 2)
      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[1].sale, sale3.address)
    })

    it("should throw adding a SA to a not existing sa", async function () {

      await assertThrowsMessage(
          storage.connect(manager).addNewSA(20, newSA),
          'SAStorage: Bundle does not exist')

    })


  })

  describe('#updateSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should update a sale", async function () {

      let saId = 2

      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)

      let newSA = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await storage.connect(manager).addNewSA(saId, newSA)
      await storage.connect(manager).updateSA(saId, 1, 50, 50)
      assert.equal((await storage.getBundle(saId)).sas[1].remainingAmount, 50)
    })

    it("should throw updating a not existing sa", async function () {

      await assertThrowsMessage(
          storage.connect(manager).updateSA(10, 0, 50, 50),
          'SAStorage: Bundle does not exist')

    })

    it("should throw updating a not existing listed sale", async function () {

      await assertThrowsMessage(
          storage.connect(manager).updateSA(2, 2, 50, 50),
          'SAStorage: SA does not exist')

    })

  })



  describe('#deleteSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should delete a listed sale from an Bundle", async function () {

      let saId = 2

      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)

      await storage.connect(manager).deleteSA(saId, 0)

      assert.equal((await storage.getBundle(saId)).sas[0].sale, addr0)
    })

    it("should throw deleting a listedSale of a not existing sa", async function () {

      await assertThrowsMessage(
          storage.connect(manager).deleteSA(10, 0),
          'SAStorage: Bundle does not exist')

    })

    it("should throw deleting a not existing listed sale", async function () {

      await assertThrowsMessage(
          storage.connect(manager).deleteSA(2, 2),
          'SAStorage: SA does not exist')

    })

  })


  describe('#deleteAllSAs', async function () {

    let newSAs
    let saId = 2

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
      newSAs = [
        {
          sale: sale2.address,
          remainingAmount: 100,
          vestedPercentage: 0
        },
        {
          sale: sale3.address,
          remainingAmount: 40,
          vestedPercentage: 30
        },
        {
          sale: sale4.address,
          remainingAmount: 70,
          vestedPercentage: 70
        }
      ]
      await storage.connect(manager).addNewSAs(saId, newSAs)
    })

    it("should delete all listed sales of an Bundle", async function () {

      assert.equal((await storage.getBundle(saId)).sas[0].sale, sale1.address)
      assert.equal((await storage.getBundle(saId)).sas[1].sale, sale2.address)
      assert.equal((await storage.getBundle(saId)).sas[2].sale, sale3.address)
      assert.equal((await storage.getBundle(saId)).sas[3].sale, sale4.address)

      await storage.connect(manager).deleteAllSAs(saId)
      assert.equal((await storage.getBundle(saId)).sas.length, 0)
    })

    it("should throw adding an array of sales to a not existing sa", async function () {

      await assertThrowsMessage(
          storage.connect(manager).deleteAllSAs(20),
          'SAStorage: Bundle does not exist')

    })


  })

  })
