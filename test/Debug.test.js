const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle} = require('./helpers')

describe.only("Debug", function() {

  let Debug
  let debug

  let one, two

  before(async function () {
    [one, two] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    Debug = await ethers.getContractFactory("Debug")
    debug = await Debug.deploy()
    await debug.deployed()

  }

  describe('See gas consumption', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should use two mappings", async function () {

      await debug.associate(one.address, two.address);
      assert.isTrue(await debug.isMutualAssociatedAddress(one.address, two.address))

    })

    it("should use one mappings", async function () {

      await debug.associate2(one.address, two.address);
      assert.isTrue(await debug.isMutualAssociatedAddress2(one.address, two.address))

    })

  })

})