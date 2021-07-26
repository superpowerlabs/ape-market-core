const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle} = require('./helpers')

describe.only("TestMappings", function() {

  let TestMappings
  let testMappings

  let one, two

  before(async function () {
    [one, two] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    TestMappings = await ethers.getContractFactory("TestMappings")
    testMappings = await TestMappings.deploy()
    await testMappings.deployed()

  }

  describe('See gas consumption', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should use two mappings", async function () {

      await testMappings.associate(one.address, two.address);
      assert.isTrue(await testMappings.isMutualAssociatedAddress(one.address, two.address))

    })

    it("should use one mappings", async function () {

      await testMappings.associate2(one.address, two.address);
      assert.isTrue(await testMappings.isMutualAssociatedAddress2(one.address, two.address))

    })

  })

})