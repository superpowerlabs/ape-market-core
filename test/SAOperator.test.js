const {expect, assert} = require("chai")
const {assertThrowsMessage} = require('./helpers')

describe("SAOperator", async function () {

  let SAOperator
  let operator
  let signers

  let owner, factory, newFactory, sale1, sale2, sale3, sale4
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, factory, newFactory, sale1, sale2, sale3, sale4] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {
    SAOperator = await ethers.getContractFactory("SAOperator")
    operator = await SAOperator.deploy(factory.address)
    await operator.deployed()
  }

  async function prePopulate() {
    let saId = 0
    await operator.connect(factory).addSABox(saId++, sale1.address, 0, 100)
    await operator.connect(factory).addSABox(saId++, sale2.address, 0, 100)
    await operator.connect(factory).addSABox(saId++, sale1.address, 10, 90)
    await operator.connect(factory).addSABox(saId++, sale2.address, 30, 50)
  }

  describe('#constructor & #getFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the factory is correctly set", async function () {
      assert.equal((await operator.getFactory()), factory.address)
    })

  })

  describe('#setFactory', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should update the factory", async function () {
      await expect(operator.setFactory(newFactory.address))
          .to.emit(operator, 'FactorySet')
          .withArgs(newFactory.address)
      assert.equal((await operator.getFactory()), newFactory.address)
    })

  })

  describe('#addSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should add new sale to the _sas", async function () {

      let saId = 3

      await expect(operator.connect(factory).addSABox(saId, sale1.address, 0, 100))
          .to.emit(operator, 'SABoxAdded')
          .withArgs(saId, sale1.address, 0, 100)
      assert.equal((await operator.getSABox(saId)).sas[0].sale, sale1.address)
    })

    it("should throw adding again the same sale id", async function () {

      let saId = 3

      await operator.connect(factory).addSABox(saId, sale1.address, 0, 100)

      await assertThrowsMessage(
          operator.connect(factory).addSABox(saId, sale1.address, 20, 20),
          'SAOperator: SABox already added')

    })
  })

  describe('#deleteSABox', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should delete a sale", async function () {

      let saId = 3
      await operator.connect(factory).addSABox(saId, sale1.address, 0, 100)
      await expect(operator.connect(factory).deleteSABox(saId))
          .to.emit(operator, 'SABoxDeleted')
          .withArgs(saId)
      assert.isUndefined((await operator.getSABox(saId)).sas[0])
    })

    it("should throw deleting a not existing sa", async function () {

      let saId = 3

      await assertThrowsMessage(
          operator.connect(factory).deleteSABox(saId),
          'SAOperator: SABox does not exist')

    })

  })

  describe('#updateSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should update a sale", async function () {

      let saId = 2

      assert.equal((await operator.getSABox(saId)).sas[0].sale, sale1.address)

      let newSA = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await operator.connect(factory).updateSA(saId, 0, newSA)
      assert.equal((await operator.getSABox(saId)).sas[0].sale, sale3.address)
    })

    it("should throw updating a not existing sa", async function () {

      let newSA = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await assertThrowsMessage(
          operator.connect(factory).updateSA(10, 0, newSA),
          'SAOperator: SABox does not exist')

    })

    it("should throw updating a not existing listed sale", async function () {

      let newSA = {
        sale: sale3.address,
        remainingAmount: 100,
        vestedPercentage: 0
      }

      await assertThrowsMessage(
          operator.connect(factory).updateSA(2, 2, newSA),
          'SAOperator: SA does not exist')

    })

  })


  describe('#deleteSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
    })

    it("should delete a listed sale from an SABox", async function () {

      let saId = 2

      assert.equal((await operator.getSABox(saId)).sas[0].sale, sale1.address)

      await operator.connect(factory).deleteSA(saId, 0)

      assert.equal((await operator.getSABox(saId)).sas[0].sale, addr0)
    })

    it("should throw deleting a listedSale of a not existing sa", async function () {

      await assertThrowsMessage(
          operator.connect(factory).deleteSA(10, 0),
          'SAOperator: SABox does not exist')

    })

    it("should throw deleting a not existing listed sale", async function () {

      await assertThrowsMessage(
          operator.connect(factory).deleteSA(2, 2),
          'SAOperator: SA does not exist')

    })

  })

  describe('#addNewSAs', async function () {

    let newSAs

    beforeEach(async function () {
      await initNetworkAndDeploy()
      await prePopulate()
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
    })

    it("should add an array of sales", async function () {

      let saId = 2

      await operator.connect(factory).addNewSAs(saId, newSAs)
      assert.equal((await operator.getSABox(saId)).sas.length, 3)
      assert.equal((await operator.getSABox(saId)).sas[0].sale, sale1.address)
      assert.equal((await operator.getSABox(saId)).sas[1].sale, sale3.address)
      assert.equal((await operator.getSABox(saId)).sas[2].sale, sale4.address)
    })

    it("should throw adding an array of sales to a not existing sa", async function () {

      await assertThrowsMessage(
          operator.connect(factory).addNewSAs(20, newSAs),
          'SAOperator: SABox does not exist')

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
      await operator.connect(factory).addNewSAs(saId, newSAs)
    })

    it("should delete all listed sales of an SABox", async function () {

      assert.equal((await operator.getSABox(saId)).sas[0].sale, sale1.address)
      assert.equal((await operator.getSABox(saId)).sas[1].sale, sale2.address)
      assert.equal((await operator.getSABox(saId)).sas[2].sale, sale3.address)
      assert.equal((await operator.getSABox(saId)).sas[3].sale, sale4.address)

      await operator.connect(factory).deleteAllSAs(saId)
      assert.equal((await operator.getSABox(saId)).sas.length, 0)
    })

    it("should throw adding an array of sales to a not existing sa", async function () {

      await assertThrowsMessage(
          operator.connect(factory).deleteAllSAs(20),
          'SAOperator: SABox does not exist')

    })


  })




})
