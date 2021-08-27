// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { expect } = require("chai");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile 
  // manually to make sure everything is compiled
  let apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2;
  hre.run('compile');
  // ****** IMPORTANT: The ordering of the tests reflects operation flows and needs
  // to be maintained accordingly.

  [apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2] = await ethers.getSigners();
  console.log("apeOwner", apeOwner.address);
  console.log("tetherOwner", tetherOwner.address);
  console.log("abcOwner", abcOwner.address);
  console.log("xyzOwner", xyzOwner.address);
  console.log("investor1", investor1.address);
  console.log("investor2", investor2.address);

  let Tether, tether;

  Tether = await hre.ethers.getContractFactory("Tether");
  tether = await Tether.connect(tetherOwner).deploy("NEWTether", "NEWUSDT");
  await tether.deployed();
  console.log("Tether deployed to:", tether.address);

  await tether.connect(tetherOwner).transfer(investor1.address, "40000");
  console.log((await tether.balanceOf(investor1.address)).toNumber());
  await tether.connect(tetherOwner).transfer(investor2.address, "50000");
  console.log((await tether.balanceOf(investor2.address)).toNumber());

  let Token, abc;

  Token = await hre.ethers.getContractFactory("Token");
  abc = await Token.connect(abcOwner).deploy("ABC", "ABC");
  await abc.deployed();
  console.log("ABC deployed to:", abc.address);

  let xyz;

  xyz = await Token.connect(xyzOwner).deploy("XYZ", "XYZ");
  await xyz.deployed();
  console.log("XYZ deployed to:", xyz.address);

  let SANFT, saNFT;

  SANFT = await hre.ethers.getContractFactory("SANFT");
  saNFT = await SANFT.deploy(tether.address, 100);
  console.log("SANFT deployed to:", saNFT.address);

  let Sale, setup, vestingSchedule

  Sale = await hre.ethers.getContractFactory("Sale");
  setup = { saNFT: saNFT.address,
              saleBeginTime: 0,
              duration: 100000,
              minAmount: 100,
              capAmount: 20000,
              remainingAmount: 0,
              price: 2,
              sellingToken:  abc.address,
              paymentToken: tether.address,
              owner: abcOwner.address,
              tokenListTimestamp: 0,
              tokenFeePercentage: 5,
              paymentFeePercentage: 10,
           };
  vestingSchedule = [{timestamp: 10, percentage: 50}, {timestamp: 1000, percentage: 100}]


  let abcSale;

  abcSale = await Sale.deploy(setup, vestingSchedule);
  console.log("ABC Sale deployed to:", abcSale.address);

  await abc.connect(abcOwner).approve(abcSale.address, setup.capAmount);
  await abcSale.connect(abcOwner).launch()
  // expect(await abc.balanceOf(abcSale.address)).to.equal(setup.capAmount);

  let xyzSale

  setup.owner = xyzOwner.address;
  setup.sellingToken = xyz.address;
  setup.price = 1;
  xyzSale = await Sale.deploy(setup, vestingSchedule);
  console.log("XYZ Sale deployed to:", xyzSale.address);

  await xyz.connect(xyzOwner).approve(xyzSale.address, setup.capAmount);
  await xyzSale.connect(xyzOwner).launch()
  // expect(await xyz.balanceOf(xyzSale.address)).to.equal(setup.capAmount);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
