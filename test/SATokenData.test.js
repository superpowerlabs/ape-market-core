const {expect, assert} = require("chai")

describe("SANFTData", function () {

  let SANFTData
  let tokenData
  let SaleData
  let saleData
  let Sale
  let sale1
  let sale2
  let saleId1 = 54323
  let saleId2 = 3

  let now

  let day = 60 * 60 * 24

  let owner, apeWallet

  let addr0 = '0x0000000000000000000000000000000000000000'


  before(async function () {
    [owner, apeWallet] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    SaleData = await ethers.getContractFactory("SaleDataMock")
    saleData = await SaleData.deploy(apeWallet.address)
    await saleData.deployed()

    Sale = await ethers.getContractFactory("Sale")
    sale1 = await Sale.deploy(saleId1, saleData.address)
    await sale1.deployed()
    sale2 = await Sale.deploy(saleId2, saleData.address)
    await sale2.deployed()

    SANFTData = await ethers.getContractFactory("SANFTDataMock")
    tokenData = await SANFTData.deploy(saleData.address)
    await tokenData.deployed()

  }

  describe('#_packSA', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should successfully pack an SA and unpack a uint256", async function () {

      let sa = {
        sale: sale1.address,
        remainingAmount: '2783674444453465480000000000000007',
        vestedPercentage: 100
      }

      let uint = await tokenData.packSA(sa)
      let sa2 = await tokenData.unpackUint256(uint)
      assert.equal(sa.sale, sale1.address)
      assert.equal(sa.vestedPercentage, sa2.vestedPercentage.toNumber())
      assert.equal(sa.remainingAmount, sa2.remainingAmount.toString())

      sa = {
        sale: sale2.address,
        remainingAmount: '65480000000000000000',
        vestedPercentage: 15
      }

      uint = await tokenData.packSA(sa)
      sa2 = await tokenData.unpackUint256(uint)
      assert.equal(sa.sale, sale2.address)
      assert.equal(sa.vestedPercentage, sa2.vestedPercentage.toNumber())
      assert.equal(sa.remainingAmount, sa2.remainingAmount.toString())

    })


  })




})
