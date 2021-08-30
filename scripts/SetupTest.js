// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const {expect, assert} = require("chai")
const DeployUtils = require('./lib/DeployUtils')
const Deployed = require('../config/deployed.json')
const {
  initEthers,
  signPackedData,
  assertThrowsMessage,
  addr0
} = require('../scripts/lib/TestHelpers')

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')
const apeRegistryJson = require('../artifacts/contracts/registry/ApeRegistry.sol/ApeRegistry.json')

async function main() {

  const deployUtils = new DeployUtils(ethers)
  initEthers(ethers)
  const chainId = (await ethers.provider.getNetwork()).chainId

  let apeRegistry
      , profile
      , saleSetupHasher
      , saleData
      , saleDB
      , saleFactory
      , sANFT
      , sANFTManager
      , tokenRegistry
      , sellingToken
      , sellingToken2
      , tether
      , saleSetup
      , saleVestingSchedule
      , owner
      , validator
      , operator
      , apeWallet
      , seller
      , buyer
      , buyer2
      , saleAddress
      , saleId
      , sale
      , saleAddress2
      , saleId2
      , sale2

  async function getSignatureByValidator(saleId, setup, schedule = []) {
    return signPackedData(saleSetupHasher, 'packAndHashSaleConfiguration',
      '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', saleId.toNumber(), setup, schedule, tether.address)
  }

  function normalize(val, n = 18) {
    return '' + val + '0'.repeat(n)
  }

  [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()

  apeRegistryAddress = Deployed[chainId].ApeRegistry
  
  console.log(apeRegistryAddress)

  apeRegistry = new ethers.Contract(apeRegistryAddress, apeRegistryJson.abi, owner)

  console.log(apeRegistry)

  profile = await apeRegistry.get(ethers.utils.id("profile"))
  console.log(profile)


      'SaleSetupHasher',
      'SaleDB',
      'SaleData',
      'SaleFactory',
      'SANFT',
      'SANFTManager',
      'TokenRegistry'

  saleSetupHasher = await results.saleSetupHasher
  saleData = results.saleData
  saleDB = results.saleDB
  saleFactory = results.saleFactory
  sANFT = results.sANFT
  sANFTManager = results.sANFTManager
  tokenRegistry = results.tokenRegistry
  tether = results.tetherMock

  sellingToken = await deployUtils.deployContractBy("ERC20Token", seller, "Abc Token", "ABC")

  await (await tether.transfer(buyer.address, normalize(40000, 6))).wait()
  await (await tether.transfer(buyer2.address, normalize(50000, 6))).wait()

  saleVestingSchedule = [
    {
      waitTime: 0,
      percentage: 20
    },
    {
      waitTime: 30,
      percentage: 50
    },
    {
      waitTime: 90,
      percentage: 100
    }
  ]

  const [schedule, msg] = await saleData.validateAndPackVestingSteps(saleVestingSchedule)

  saleSetup = {
    owner: seller.address,
    minAmount: 30,
    capAmount: 20000,
    tokenListTimestamp: 0,
    remainingAmount: 0,
    pricingToken: 1,
    pricingPayment: 2,
    paymentTokenId: 0,
    vestingSteps: schedule[0],
    sellingToken: sellingToken.address,
    totalValue: 50000,
    tokenIsTransferable: true,
    tokenFeePoints: 500,
    extraFeePoints: 0,
    paymentFeePoints: 300,
    saleAddress: addr0
  };

  saleId = await saleDB.nextSaleId()

  await saleFactory.connect(operator).approveSale(saleId)

  let signature = await getSignatureByValidator(saleId, saleSetup)

  await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address, signature))
      .emit(saleFactory, "NewSale")
  saleAddress = await saleDB.getSaleAddressById(saleId)
  sale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
  assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

  await sellingToken.connect(seller).approve(saleAddress, await saleData.fromValueToTokensAmount(saleId, saleSetup.totalValue * 1.05))
  await sale.connect(seller).launch()

  await tether.connect(buyer).approve(saleAddress, normalize(400, 6));
  await saleData.connect(seller).approveInvestor(saleId, buyer.address, normalize(200, 6))
  await sale.connect(buyer).invest(200)
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
