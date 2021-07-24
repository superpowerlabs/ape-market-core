const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle} = require('./helpers')

describe.only("Debug", function() {

  let Debug
  let debug

  let saleSetup
  let saleVestingSchedule

  let owner, satoken, abc, abcOwner, tether
  let addr0 = '0x0000000000000000000000000000000000000000'

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

    saleSetup = {
      satoken: satoken.address,
      sellingToken: abc.address,
      paymentToken: tether.address,
      owner: abcOwner.address,
      remainingAmount: 0,
      minAmount: 100,
      capAmount: 20000,
      pricingToken: 1,
      pricingPayment: 2,
      tokenListTimestamp: 0,
      tokenFeePercentage: 5,
      paymentFeePercentage: 10,
      tokenIsTransferable: true
    };
    saleVestingSchedule = [
      {
        timestamp: 10,
        percentage: 50
      },
      {
        timestamp: 1000,
        percentage: 100
      }]
  }

  describe('See gas consumption', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should set Setup and VestingStep", async function () {


      await debug.setSetup(saleSetup);
      await debug.setVesting(saleVestingSchedule);

    })

    it("should set Setup2 and VestingStep2", async function () {



      await debug.setSetup2(saleSetup);
      await debug.setVesting2(saleVestingSchedule);

    })


  })


})