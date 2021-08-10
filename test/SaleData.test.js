const {assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')

describe("SaleData", async function () {

  const deployUtils = new DeployUtils(ethers)

  let apeRegistry
      , profile
      , saleSetupHasher
      , saleData
      , saleFactory
      , sANFT
      , sANFTManager
      , tokenRegistry
      , owner
      , validator
      , operator
      , apeWallet

  before(async function () {
    [owner, validator, operator, apeWallet] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    const results = await deployUtils.initAndDeploy({
      apeWallet: apeWallet.address,
      validators: [validator.address],
      operators: [operator.address]
    })

    apeRegistry = results.apeRegistry
    profile = results.profile
    saleSetupHasher = results.saleSetupHasher
    saleData = results.saleData
    saleFactory = results.saleFactory
    sANFT = results.sANFT
    sANFTManager = results.sANFTManager
    tokenRegistry = results.tokenRegistry

  }

  describe('#vestingSteps', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should save a 34 vesting steps array in 3 uint256 and correctly calculate the vested percentage", async function () {
      let schedule = []
      let size = 35
      for (let i=1; i<=size; i++) {
        schedule.push({
          waitTime: i * 10,
          percentage:
              i === size ? 100 : i
        })
      }
      let [steps, message] = await saleData.validateAndPackVestingSteps(schedule)

      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044530), 0);
      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044542 + (20 * 24 * 3600)), 2);
      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044542 + (70 * 24 * 3600)), 7);
      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044542 + (115 * 24 * 3600)), 11);
      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044542 + (1000 * 24 * 3600)), 100);

    })

    it("should vest 30% at TGE and 100 after a year", async function () {
      let schedule = [{
          waitTime: 0,
          percentage: 30, // 30% at TGE
        }, {
        waitTime: 365,
        percentage: 100
      }
        ]
      let [steps, message] = await saleData.validateAndPackVestingSteps(schedule)

      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044542), 30);
      assert.equal(await saleData.calculateVestedPercentage(steps[0], steps.slice(1), 1628044542, 1628044542 + (365 * 24 * 3600)), 100);

    })

  })

})
