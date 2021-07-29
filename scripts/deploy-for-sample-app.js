// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const {assert, expect} = require("chai");

const path = require('path')
const fs = require('fs-extra')

const DeployUtils = require('./lib/DeployUtils')
const saleJson = require('../src/artifacts/contracts/sale/Sale.sol/Sale.json')
const saleFactoryJson = require('../src/artifacts/contracts/sale/SaleFactory.sol/SaleFactory.json')
const tetherMockJson = require('../src/artifacts/contracts/test/TetherMock.sol/TetherMock.json')


function normalize(amount) {
  return '' + amount + '0'.repeat(18);
}

function normalizeMinMaxAmount (amount) {
  return '' + amount + '0'.repeat(15);
}


async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.

  await hre.run('compile');

  const ethers = hre.ethers

  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // ****** IMPORTANT: The ordering of the tests reflects operation flows and needs
  // to be maintained accordingly.

  const [apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2 , apeWallet, factoryAdmin] = await hre.ethers.getSigners()
  console.log("apeOwner", apeOwner.address);
  console.log("tetherOwner", tetherOwner.address);
  console.log("abcOwner", abcOwner.address);
  console.log("xyzOwner", xyzOwner.address);
  console.log("investor1", investor1.address);
  console.log("investor2", investor2.address);
  console.log("apeWallet", apeWallet.address);
  console.log("factoryAdmin", factoryAdmin.address);

  const deployUtils = new DeployUtils(hre.ethers)
  const chainId = await deployUtils.currentChainId()
  console.log('Deploying contracts...')

  let data = await deployUtils.initAndDeploy()

  console.log('Result addresses:\n', data)

  assert.equal(tetherOwner.address, data.tetherOwner)

  const tetherAddress = data.tether
  let tether = new hre.ethers.Contract(tetherAddress, tetherMockJson.abi, ethers.provider)

  await tether.connect(tetherOwner).transfer(investor1.address, "40000");
  console.log((await tether.balanceOf(investor1.address)).toNumber());
  await tether.connect(tetherOwner).transfer(investor2.address, "50000");
  console.log((await tether.balanceOf(investor2.address)).toNumber());

  let Token, abc;

  Token = await hre.ethers.getContractFactory("ERC20Token");
  abc = await Token.connect(abcOwner).deploy("ABC", "ABC");
  await abc.deployed();
  console.log("ABC deployed to:", abc.address);
  const AbcAddress = abc.address;

  let xyz;

  xyz = await Token.connect(xyzOwner).deploy("XYZ", "XYZ");
  await xyz.deployed();
  console.log("XYZ deployed to:", xyz.address);
  const XyzAddress = xyz.address;

  let saleSetup = {
    satoken: data.SAToken,
    minAmount: 100000,
    capAmount: 20000000,
    remainingAmount: 0,
    pricingToken: 1,
    pricingPayment: 2,
    sellingToken: abc.address,
    paymentToken: tether.address,
    owner: abcOwner.address,
    tokenListTimestamp: 0,
    tokenFeePercentage: 5,
    paymentFeePercentage: 10,
    tokenIsTransferable: true
  };
  let saleVestingSchedule = [
    {
      timestamp: 10,
      percentage: 50
    },
    {
      timestamp: 1000,
      percentage: 100
    }]

  const factory = new ethers.Contract(data.SaleFactory, saleFactoryJson.abi, ethers.provider)

  console.log('SaleFactory at ', factory.address)

    await expect(factory.connect(factoryAdmin).newSale(saleSetup, saleVestingSchedule, apeWallet.address, data.SaleData))
    .to.emit(factory, "NewSale")

  const AbcSaleAddress = await factory.lastSale()

  const abcSale = new ethers.Contract(AbcSaleAddress, saleJson.abi, ethers.provider)
  const abcSaleId = await abcSale.saleId()

  await abc.connect(abcOwner).approve(AbcSaleAddress, normalizeMinMaxAmount(saleSetup.capAmount * 1.05));
  await abcSale.connect(abcOwner).launch()
  expect(await abc.balanceOf(AbcSaleAddress)).to.equal(normalizeMinMaxAmount(saleSetup.capAmount * 1.05));

  console.log("ABC Sale deployed to:", AbcSaleAddress);

  saleSetup.owner = xyzOwner.address;
  saleSetup.sellingToken = xyz.address;
  saleSetup.pricingToken = 1;

  await factory.connect(factoryAdmin).newSale(saleSetup, saleVestingSchedule, apeWallet.address,data.SaleData)
  const XyzSaleAddress = await factory.lastSale()

  const xyzSale = new ethers.Contract(XyzSaleAddress, saleJson.abi, ethers.provider)

  console.log("XYZ Sale deployed to:", XyzSaleAddress);

  await xyz.connect(xyzOwner).approve(XyzSaleAddress, normalizeMinMaxAmount(saleSetup.capAmount * 1.05));
  await xyzSale.connect(xyzOwner).launch()
  expect(await xyz.balanceOf(XyzSaleAddress)).to.equal(normalizeMinMaxAmount(saleSetup.capAmount * 1.05));

  data = Object.assign(data, {
    AbcAddress,
    XyzAddress,
    AbcSaleAddress,
    XyzSaleAddress,
    investor1: investor1.address
  })

  console.log(data)
  await deployUtils.saveConfig(chainId, data)

}



// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
