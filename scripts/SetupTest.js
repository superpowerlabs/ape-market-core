// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const {expect, assert} = require("chai")
const DeployUtils = require('./lib/DeployUtils')
const Deployed = require('../config/deployed.json')
const {
  initEthers,
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
    console.log("Getting contract from registry", contractName)
    contractAddress = await apeRegistry.get(ethers.utils.id(contractName))
    console.log(contractAddress)
    console.log("Got contract from registry", contractName)
    return new ethers.Contract(contractAddress, abi, owner)
  }

  const deployUtils = new DeployUtils(ethers)
  initEthers(ethers)
  const chainId = (await ethers.provider.getNetwork()).chainId

  let [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()

  apeRegistryAddress = Deployed[chainId].ApeRegistry

  console.log(apeRegistryAddress)

  tetherAddress = Deployed[chainId].paymentTokens.USDT

  console.log(tetherAddress)

  let apeRegistry = new ethers.Contract(apeRegistryAddress, ApeRegistryJson.abi, owner)
  let tether = new ethers.Contract(tetherAddress, TetherMockJson.abi, owner)

  sellingToken = await deployUtils.deployContractBy("ERC20Token", seller, "Abc Token", "ABC")
  console.log("sellingTokenAddress", sellingToken.address)

  await (await tether.transfer(buyer.address, normalize(40000, 6))).wait()
  await (await tether.transfer(buyer2.address, normalize(50000, 6))).wait()
  console.log("transferring usdt done")

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
  let saleSetupHasher = await getContractFromRegistry("SaleSetupHasher", SaleSetupHasherJson.abi, owner)

  console.log("Packing Hash")
  const [schedule, msg] = await saleSetupHasher.validateAndPackVestingSteps(saleVestingSchedule)

  console.log("Hash packed")

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

    hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)

    saleFactory = await getContractFromRegistry("SaleFactory", SaleFactoryJson.abi, owner)

    transaction = await saleFactory.connect(operator).approveSale(hash)

    await transaction.wait()

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

    transaction = await saleFactory.connect(operator).approveSale(hash)

    await transaction.wait()

    saleId = await saleFactory.getSaleIdBySetupHash(hash)

    await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address))
        .emit(saleFactory, "NewSale")

    saleDB = await getContractFromRegistry("SaleDB", SaleDBJson.abi, owner)
    saleAddress = await saleDB.getSaleAddressById(saleId)
    sale = new ethers.Contract(saleAddress, SaleJson.abi, ethers.provider)
    assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

    await sellingToken.connect(seller).approve(saleAddress, await saleData.fromValueToTokensAmount(saleId, saleSetup.totalValue * 1.05))
    await sale.connect(seller).launch()

    await tether.connect(buyer).approve(saleAddress, normalize(400, 6));
    await saleData.connect(seller).approveInvestors(saleId, [buyer.address], [normalize(200, 6)])
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
