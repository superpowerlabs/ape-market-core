const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle} = require('./helpers')

describe.only("Debug", function() {

  let Debug
  let debug

  let owner, satoken, abc, abcOwner, tether
  // let addr0 = '0x0000000000000000000000000000000000000000'

  before(async function () {
    [owner, satoken, abc, abcOwner, tether] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

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

      await debug.associate(owner.address, satoken.address);

    })

    it("should use one mappings", async function () {

      await debug.associate2(owner.address, satoken.address);

    })

  })

})