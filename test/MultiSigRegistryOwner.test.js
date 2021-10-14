const {assert, expect} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')
const {
  assertThrowsMessage,
  getTimestamp
} = require('../scripts/lib/TestHelpers')

describe("MultiSigRegistryOwner", async function () {

  const deployUtils = new DeployUtils(ethers)

  let apeRegistry
      , multiSigRegistryOwner
      , profile
      , profile2
      , owner
      , validator
      , operator
      , apeWallet
      , signer1, signer2, signer3

  before(async function () {
    [owner, validator, operator, apeWallet, signer1, signer2, signer3] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    const results = await deployUtils.initAndDeploy({
      apeWallet: apeWallet.address,
      operators: [operator.address],
      signersList: [
        signer1.address,
        signer2.address,
        signer3.address
      ],
      validity: 24 * 3600
    })

    apeRegistry = results.apeRegistry
    profile = results.profile
    profile2 = await deployUtils.deployContract('Profile')
    multiSigRegistryOwner = results.multiSigRegistryOwner

  }

  describe('initial setting', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the signers are correctly set up", async function () {
      const signersList = await multiSigRegistryOwner.getSigners()
      assert.isTrue(!!~signersList.indexOf(signer1.address))
      assert.isTrue(!!~signersList.indexOf(signer2.address))
      assert.isTrue(!!~signersList.indexOf(signer3.address))
    })

  })

  describe('update the registry', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should execute the first order and verify that Profile has not changed", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600 // one hour ago
      const profileId = ethers.utils.id('Profile')
      await multiSigRegistryOwner.connect(signer1).register(
          [profileId],
          [profile2.address],
          orderTimestamp
      )
      const order = await multiSigRegistryOwner.getOrderHash(
          [ethers.utils.id('Profile')],
          [profile2.address],
          orderTimestamp
      )
      const currentSigners = await multiSigRegistryOwner.getSignersByOrder(order)
      assert.equal(currentSigners.length, 1)
      assert.equal(currentSigners[0], signer1.address)

      const profileAddress = await apeRegistry.get(profileId)
      assert.equal(profileAddress, profile.address)
    })

    it("should execute first and second order, reaching the quorum, and verify that Profile changed", async function () {
      const orderTimestamp = (await getTimestamp()) - 3600 // one hour ago
      const profileId = ethers.utils.id('Profile')
      await multiSigRegistryOwner.connect(signer1).register(
          [profileId],
          [profile2.address],
          orderTimestamp
      )
      const order = await multiSigRegistryOwner.getOrderHash(
          [profileId],
          [profile2.address],
          orderTimestamp
      )
      await multiSigRegistryOwner.connect(signer2).register(
          [ethers.utils.id('Profile')],
          [profile2.address],
          orderTimestamp
      )
      const currentSigners = await multiSigRegistryOwner.getSignersByOrder(order)
      assert.equal(currentSigners.length, 0)

      const profileAddress = await apeRegistry.get(profileId)
      assert.equal(profileAddress, profile2.address)
    })

    it("should throw if the deployer of ApeRegistry tries to register again", async function () {
      const profileId = ethers.utils.id('Profile')
      assertThrowsMessage(apeRegistry.register([profileId], [profile2.address]),
          "not the multi sig owner");

    })

  })

})
