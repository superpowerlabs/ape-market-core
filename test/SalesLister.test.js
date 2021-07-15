const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe.only("SalesLister", async function () {

  let SalesLister
  let lister
  let signers

  let owner, factory, newFactory, sale1, sale2, sale3, sale4
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    signers = await ethers.getSigners()
    owner = signers[0]
    factory = signers[1]
    newFactory = signers[2]
    sale1 = signers[3]
    sale2 = signers[4]
    sale3 = signers[5]
    sale4 = signers[6]
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {
    SalesLister = await ethers.getContractFactory("SalesLister")
    lister = await SalesLister.deploy(factory.address)
    await lister.deployed()
  }

  async function prePopulate() {
    let saId = 0
    await lister.connect(factory).addSA(saId++, sale1.address, 0, 100)
    await lister.connect(factory).addSA(saId++, sale2.address, 0, 100)
    await lister.connect(factory).addSA(saId++, sale1.address, 10, 90)
    await lister.connect(factory).addSA(saId++, sale2.address, 30, 50)
  }

  describe('#constructor & #getFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the factory is correctly set", async function () {
      assert.equal((await lister.getFactory()), factory.address)
    })

  })

  describe('#setFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should update the factory", async function () {
      await expect(lister.setFactory(newFactory.address))
          .to.emit(lister, 'FactorySet')
          .withArgs(newFactory.address)
      assert.equal((await lister.getFactory()), newFactory.address)
    })

  })

  describe('#addSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should add new sale to the _sas", async function () {

      let saId = 3

      await expect(lister.connect(factory).addSA(saId, sale1.address, 0, 100))
          .to.emit(lister, 'SAAdded')
          .withArgs(saId, sale1.address, 0, 100)
      assert.equal((await lister.getSA(saId)).listedSales[0].sale, sale1.address)
    })

    it("should throw adding again the same sale id", async function () {

      let saId = 3

      await lister.connect(factory).addSA(saId, sale1.address, 0, 100)

      await assertThrowsMessage(
          lister.connect(factory).addSA(saId, sale1.address, 20, 20),
          'SalesLister: SA already added')

    })
  })

  describe('#deleteSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should delete a sale", async function () {

      let saId = 3
      await lister.connect(factory).addSA(saId, sale1.address, 0, 100)
      await expect(lister.connect(factory).deleteSA(saId))
          .to.emit(lister, 'SADeleted')
          .withArgs(saId)
      assert.isUndefined((await lister.getSA(saId)).listedSales[0])
    })

    it("should throw deleting a not existing sa", async function () {

      let saId = 3

      await assertThrowsMessage(
          lister.connect(factory).deleteSA(saId),
          'SalesLister: SA does not exist')

    })

  })

  describe('#updateListedSale', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should update a sale", async function () {

      let saId = 2

      assert.equal((await lister.getSA(saId)).listedSales[0].sale, sale1.address)

      let newListedSale = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await lister.connect(factory).updateListedSale(saId, 0, newListedSale)
      assert.equal((await lister.getSA(saId)).listedSales[0].sale, sale3.address)
    })

    it("should throw updating a not existing sa", async function () {

      let newListedSale = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await assertThrowsMessage(
          lister.connect(factory).updateListedSale(10, 0, newListedSale),
          'SalesLister: SA does not exist')

    })

    it("should throw updating a not existing listed sale", async function () {

      let newListedSale = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await assertThrowsMessage(
          lister.connect(factory).updateListedSale(2, 2, newListedSale),
          'SalesLister: Listed sale does not exist')

    })

  })


  describe('#deleteListedSale', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should delete a listed sale from an SA", async function () {

      let saId = 2

      assert.equal((await lister.getSA(saId)).listedSales[0].sale, sale1.address)

      await lister.connect(factory).deleteListedSale(saId, 0)

      assert.equal((await lister.getSA(saId)).listedSales[0].sale, addr0)
    })

    it("should throw deleting a listedSale of a not existing sa", async function () {

      await assertThrowsMessage(
          lister.connect(factory).deleteListedSale(10, 0),
          'SalesLister: SA does not exist')

    })

    it("should throw deleting a not existing listed sale", async function () {

      await assertThrowsMessage(
          lister.connect(factory).deleteListedSale(2, 2),
          'SalesLister: Listed sale does not exist')

    })

  })

  describe('#addNewSales', async function () {

    let newListedSales

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
      newListedSales = [
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
    })

    it("should add an array of sales", async function () {

      let saId = 2

      await lister.connect(factory).addNewSales(saId, newListedSales)
      assert.equal((await lister.getSA(saId)).listedSales.length, 3)
      assert.equal((await lister.getSA(saId)).listedSales[0].sale, sale1.address)
      assert.equal((await lister.getSA(saId)).listedSales[1].sale, sale3.address)
      assert.equal((await lister.getSA(saId)).listedSales[2].sale, sale4.address)
    })

    it("should throw adding an array of sales to a not existing sa", async function () {

      await assertThrowsMessage(
          lister.connect(factory).addNewSales(20, newListedSales),
          'SalesLister: SA does not exist')

    })


  })

  describe('#deleteAllListedSales', async function () {

    let newListedSales
    let saId = 2

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
      newListedSales = [
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
      await lister.connect(factory).addNewSales(saId, newListedSales)
    })

    it("should delete all listed sales of an SA", async function () {

      assert.equal((await lister.getSA(saId)).listedSales[0].sale, sale1.address)
      assert.equal((await lister.getSA(saId)).listedSales[1].sale, sale2.address)
      assert.equal((await lister.getSA(saId)).listedSales[2].sale, sale3.address)
      assert.equal((await lister.getSA(saId)).listedSales[3].sale, sale4.address)

      await lister.connect(factory).deleteAllListedSales(saId)
      assert.equal((await lister.getSA(saId)).listedSales.length, 0)
    })

    it("should throw adding an array of sales to a not existing sa", async function () {

      await assertThrowsMessage(
          lister.connect(factory).deleteAllListedSales(20),
          'SalesLister: SA does not exist')

    })


  })




})
