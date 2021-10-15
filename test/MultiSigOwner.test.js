const {assert, expect} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {
  assertThrowsMessage,
  getTimestamp
} = require('../scripts/lib/TestHelpers')

describe("MultiSigOwner", async function () {

  const deployUtils = new DeployUtils(ethers)

  let multiSigOwner
      , owner, signer1, signer2, signer3, signer4, signer5
      , signersList, validity

  before(async function () {
    [owner, signer1, signer2, signer3, signer4, signer5] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    signersList = [
      signer1.address,
      signer2.address,
      signer3.address
    ]
    validity = 24 * 3600

    multiSigOwner = await deployUtils.deployContract('MultiSigOwnerMock', signersList, validity)

  }

  describe('#constructor', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the signers are correctly set up", async function () {
      const signersList = await multiSigOwner.getSigners()
      assert.isTrue(!!~signersList.indexOf(signer1.address))
      assert.isTrue(!!~signersList.indexOf(signer2.address))
      assert.isTrue(!!~signersList.indexOf(signer3.address))
    })

  })

  describe('update the validity', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should execute the first order and verify that the order is not executed", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600 // one hour ago
      const newValidity = 36 * 3600 // one day and a half
      await multiSigOwner.connect(signer1).updateValidity(newValidity, orderTimestamp)
      const order = await multiSigOwner.getValidityOrder(
          newValidity,
          orderTimestamp
      )
      const currentSigners = await multiSigOwner.getSignersByOrder(order)
      assert.equal(currentSigners.length, 1)
      assert.equal(currentSigners[0], signer1.address)

      const currentValidity = await multiSigOwner.validity()
      assert.equal(validity, currentValidity)
    })

    it("should execute first and second order and verify that the order is executed", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600 // one hour ago
      const newValidity = 36 * 3600 // one day and a half
      await multiSigOwner.connect(signer1).updateValidity(newValidity, orderTimestamp)
      await multiSigOwner.connect(signer3).updateValidity(newValidity, orderTimestamp)
      const order = await multiSigOwner.getValidityOrder(
          newValidity,
          orderTimestamp
      )
      const currentSigners = await multiSigOwner.getSignersByOrder(order)
      assert.equal(currentSigners.length, 0)

      const currentValidity = await multiSigOwner.validity()
      assert.equal(newValidity, currentValidity)
    })

  })

  describe('update the signers adding 2 addresses', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should update the signers with two calls", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer4.address,
        signer5.address
      ]
      await multiSigOwner.connect(signer1).updateSigners(signersList2, [true, true], orderTimestamp)
      await multiSigOwner.connect(signer2).updateSigners(signersList2, [true, true], orderTimestamp)
      const currentSigners = await multiSigOwner.getSigners()
      assert.equal(currentSigners.length, 5)
    })

    it("should throw if removing too many signers", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer2.address,
        signer3.address
      ]
      multiSigOwner.connect(signer1).updateSigners(signersList2, [false, false], orderTimestamp)
      await assertThrowsMessage(
          multiSigOwner.connect(signer2).updateSigners(signersList2, [false, false], orderTimestamp)
          , "At least three signers are required")
    })

    it("should throw if same call from same signers", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer4.address
      ]
      multiSigOwner.connect(signer1).updateSigners(signersList2, [true], orderTimestamp)
      await assertThrowsMessage(
          multiSigOwner.connect(signer1).updateSigners(signersList2, [true], orderTimestamp)
          , "signer cannot repeat the same order")
    })

    it("should throw if empty signers", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = []
      await assertThrowsMessage(
          multiSigOwner.connect(signer1).updateSigners(signersList2, [], orderTimestamp)
          , "no changes")
    })

    it("should throw if adding already active signer", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer1.address
      ]
      await assertThrowsMessage(
          multiSigOwner.connect(signer1).updateSigners(signersList2, [true], orderTimestamp)
          , "signer already active")
    })

    it("should throw if arrays not consistent", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer1.address
      ]
      await assertThrowsMessage(
          multiSigOwner.connect(signer1).updateSigners(signersList2, [true, false], orderTimestamp)
          , "arrays are inconsistent")
    })

    it("should throw if repeating signers", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer4.address,
        signer4.address
      ]
      await assertThrowsMessage(
          multiSigOwner.connect(signer2).updateSigners(signersList2, [true, true], orderTimestamp)
          , "signer repetition")
    })

    it("should remove two of the signers with three calls", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600
      let signersList2 = [
        signer4.address,
        signer5.address
      ]
      await multiSigOwner.connect(signer1).updateSigners(signersList2, [true, true], orderTimestamp)
      await multiSigOwner.connect(signer2).updateSigners(signersList2, [true, true], orderTimestamp)
      assert.equal((await multiSigOwner.getSigners()).length, 5)
      signersList2 = [
        signer2.address,
        signer3.address
      ]
      await multiSigOwner.connect(signer1).updateSigners(signersList2, [false, false], orderTimestamp)
      await multiSigOwner.connect(signer2).updateSigners(signersList2, [false, false], orderTimestamp)
      assert.equal((await multiSigOwner.getSigners()).length, 5)
      await multiSigOwner.connect(signer5).updateSigners(signersList2, [false, false], orderTimestamp)
      assert.equal((await multiSigOwner.getSigners()).length, 3)
    })

  })

})
