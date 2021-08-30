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

const SaleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')
const ApeRegistryJson = require('../artifacts/contracts/registry/ApeRegistry.sol/ApeRegistry.json')
const SaleDataJson = require('../artifacts/contracts/sale/SaleData.sol/SaleData.json')
const SaleDBJson = require('../artifacts/contracts/sale/SaleDB.sol/SaleDB.json')
const SaleFactoryJson = require('../artifacts/contracts/sale/SaleFactory.sol/SaleFactory.json')
const TetherMockJson = require('../artifacts/contracts/test/TetherMock.sol/TetherMock.json')
const SaleSetupHasherJson = require('../artifacts/contracts/sale/SaleSetupHasher.sol/SaleSetupHasher.json')
const SANFTJson = require('../artifacts/contracts/nft/SANFT.sol/SANFT.json')

async function main() {

  function normalize(val, n = 18) {
    return '' + val + '0'.repeat(n)
  }

  async function getContractFromRegistry(contractName, abi, owner) {
    contractAddress = await apeRegistry.get(ethers.utils.id(contractName))
    return new ethers.Contract(contractAddress, abi, owner)
  }

  const deployUtils = new DeployUtils(ethers)
  initEthers(ethers)
  const chainId = (await ethers.provider.getNetwork()).chainId

  let [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()

  apeRegistryAddress = Deployed[chainId].ApeRegistry

  tetherAddress = Deployed[chainId].TetherMock

  let apeRegistry = new ethers.Contract(apeRegistryAddress, ApeRegistryJson.abi, owner)

  let tether = new ethers.Contract(tetherAddress, TetherMockJson.abi, owner)

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

  let saleData = await getContractFromRegistry("SaleData", SaleDataJson.abi, owner)

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

    saleDB = await getContractFromRegistry("SaleDB", SaleDBJson.abi, owner)

    saleId = await saleDB.nextSaleId()

    saleFactory = await getContractFromRegistry("SaleFactory", SaleFactoryJson.abi, owner)

    await saleFactory.connect(operator).approveSale(saleId)

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

    let saleSetupHasher = await getContractFromRegistry("SaleSetupHasher", SaleSetupHasherJson.abi, owner)

    async function getSignatureByValidator(saleId, setup, schedule = []) {
      return signPackedData(saleSetupHasher, 'packAndHashSaleConfiguration', '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', saleId.toNumber(), setup, schedule, tether.address)
    }

    let signature = await getSignatureByValidator(saleId, saleSetup)

    await saleFactory.connect(operator).approveSale(saleId)

    await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address, signature))
        .emit(saleFactory, "NewSale")
    saleAddress = await saleDB.getSaleAddressById(saleId)
    sale = new ethers.Contract(saleAddress, SaleJson.abi, ethers.provider)
    assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

    await sellingToken.connect(seller).approve(saleAddress, await saleData.fromValueToTokensAmount(saleId, saleSetup.totalValue * 1.05))
    await sale.connect(seller).launch()

    await tether.connect(buyer).approve(saleAddress, normalize(400, 6));
    await saleData.connect(seller).approveInvestor(saleId, buyer.address, normalize(200, 6))
    await sale.connect(buyer).invest(200)

    saNFT = await getContractFromRegistry("SANFT", SANFTJson.abi, owner)

    console.log((await saNFT.balanceOf(buyer.address)).toNumber())
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
