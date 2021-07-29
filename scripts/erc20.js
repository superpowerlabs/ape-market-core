// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  [apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2]  = await ethers.getSigners();

  Tether = await hre.ethers.getContractFactory("Tether");
  tether = await Tether.connect(tetherOwner).deploy("NEWTether", "NEWUSDT");
  await tether.deployed();
  console.log("Tether deployed to:", tether.address);

  console.log((await tether.balanceOf(investor1.address)).toNumber());
  console.log((await tether.balanceOf(investor2.address)).toNumber());
  console.log((await tether.balanceOf(tetherOwner.address)).toNumber());

  //await tether.connect(tetherOwner).approve(tetherOwner.address, "40000");
  transaction = await tether.connect(tetherOwner).transfer(investor1.address, "40000");
  console.log(await transaction.wait());

  console.log((await tether.balanceOf(investor1.address)).toNumber());
  console.log((await tether.balanceOf(investor2.address)).toNumber());
  console.log((await tether.balanceOf(tetherOwner.address)).toNumber());

  //await tether.connect(tetherOwner).approve(tetherOwner.address, "50000");
  transaction = await tether.connect(tetherOwner).transfer(investor2.address, "50000000000");
  console.log(await transaction.wait());

  console.log((await tether.balanceOf(investor1.address)).toNumber());
  console.log((await tether.balanceOf(investor2.address)).toNumber());
  console.log((await tether.balanceOf(tetherOwner.address)).toNumber());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
