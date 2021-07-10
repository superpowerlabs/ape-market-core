const hre = require("hardhat");
const { expect } = require("chai");
const delay = ms => new Promise(res => setTimeout(res, ms));

describe("Integration Test", function() {
  let apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2;
  hre.run('compile');
  // ****** IMPORTANT: The ordering of the tests reflects operation flows and needs
  // to be maintained accordingly.
  it("Integration Test", async function() {
    [apeOwner, tetherOwner, abcOwner, xyzOwner, investor1, investor2]
        = await ethers.getSigners();
    console.log("apeOwner", apeOwner.address);

  console.log(network)

  let Tether, tether;

  console.log("Deploying Tether");
  Tether = await hre.ethers.getContractFactory("Tether");
  tether = await Tether.connect(tetherOwner).deploy("Tether", "USDT");
  await tether.deployed();
  console.log("Tether deployed to:", tether.address);

  console.log("Funding investors");
  transaction = await tether.connect(tetherOwner).transfer(investor1.address, "40000");
  await transaction.wait();
  console.log((await tether.balanceOf(investor1.address)).toNumber());
  expect(await tether.balanceOf(investor1.address)).to.equal(40000);
  transaction = await tether.connect(tetherOwner).transfer(investor2.address, "50000");
  await transaction.wait();
  console.log((await tether.balanceOf(investor2.address)).toNumber());
  expect(await tether.balanceOf(investor2.address)).to.equal(50000);

  let Token, abc;
  console.log("Deploying ABC");
  Token = await hre.ethers.getContractFactory("Token");
  abc = await Token.connect(abcOwner).deploy("ABC", "ABC");
  await abc.deployed();
  console.log("ABC deployed to:", abc.address);

  let xyz;
  console.log("Deploying XYZ");
  xyz = await Token.connect(xyzOwner).deploy("XYZ", "XYZ");
  await xyz.deployed();
  console.log("XYZ deployed to:", xyz.address);

  let SANFT, saNFT;
  console.log("Deploying SANFA");
  SANFT = await hre.ethers.getContractFactory("SANFT");
  saNFT = await SANFT.deploy(tether.address, 100);
  console.log("SANFT deployed to:", saNFT.address);

  let Sale, setup, vestingSchedule
  console.log("Setting up ABC Sale");
  Sale = await hre.ethers.getContractFactory("Sale");
  setup = { saNFT: saNFT.address,
            saleBeginTime: 0,
            duration: 1000000,
            minAmount: 100,
            capAmount: 20000,
            remainingAmount: 0,
            pricingToken: 1,
            pricingPayment: 2,
            sellingToken:  abc.address,
            paymentToken: tether.address,
            owner: abcOwner.address,
            tokenListTimestamp: 0,
            tokenFeePercentage: 5,
            paymentFeePercentage: 10,
            };
  vestingSchedule = [{timestamp: 10, percentage: 50}, {timestamp: 1000, percentage: 100}]

  let abcSale;
  console.log("Deploying ABC Sale");
  abcSale = await Sale.deploy(setup, vestingSchedule);
  console.log("ABC Sale deployed to:", abcSale.address);

  console.log("Launching ABC Sale");
  transaction = await abc.connect(abcOwner).approve(abcSale.address, setup.capAmount * 1.05);
  await transaction.wait();
  transaction = await abcSale.connect(abcOwner).launch()
  await transaction.wait();
  expect(await abc.balanceOf(abcSale.address)).to.equal(setup.capAmount * 1.05);

  let xyzSale
  console.log("Deploying XYZ Sale");
  setup.owner = xyzOwner.address;
  setup.sellingToken = xyz.address;
  setup.pricingPayment = 1;
  xyzSale = await Sale.deploy(setup, vestingSchedule);
  console.log("XYZ Sale deployed to:", xyzSale.address);

  console.log("Launching XYZ Sale");
  transaction = await xyz.connect(xyzOwner).approve(xyzSale.address, setup.capAmount * 1.05);
  await transaction.wait();
  transaction = await xyzSale.connect(xyzOwner).launch()
  await transaction.wait();
  expect(await xyz.balanceOf(xyzSale.address)).to.equal(setup.capAmount * 1.05);

  console.log("Investor1 investing in ABC Sale without approval");
  // using hardcoded numbers here to simplicity
  transaction = await tether.connect(investor1).approve(abcSale.address, 10000 * 2 * 1.1);
  await transaction.wait();
  await expect(abcSale.connect(investor1).invest(10000)).to.be.revertedWith("Sale: Amount if above approved amount");

  console.log("Investor1 investing in ABC Sale with approval");
  // using hardcoded numbers here to simplicity
  transaction = await abcSale.connect(abcOwner).approveInvestor(investor1.address, 10000);
  await transaction.wait();
  transaction = await abcSale.connect(investor1).invest(6000);
  await transaction.wait();
  expect(await saNFT.balanceOf(investor1.address)).to.equal(1);
  let saId = await saNFT.tokenOfOwnerByIndex(investor1.address, 0);
  let sa = await saNFT.getSA(saId);
  expect(await sa.subSAs[0].sale).to.equal(abcSale.address);
  // 5% fee
  expect(await sa.subSAs[0].remainingAmount).to.equal(6000);
  // 10% fee
  expect(await tether.balanceOf(abcSale.address)).to.equal(6000 * 2);

  console.log("Investor1 investing in ABC Sale with approval again");
  // using hardcoded numbers here to simplicity
  await transaction.wait();
  transaction = await abcSale.connect(investor1).invest(4000);
  await transaction.wait();
  expect(await saNFT.balanceOf(investor1.address)).to.equal(2);
  saId = await saNFT.tokenOfOwnerByIndex(investor1.address, 1);
  sa = await saNFT.getSA(saId);
  expect(await sa.subSAs[0].sale).to.equal(abcSale.address);
  // 5% fee
  expect(await sa.subSAs[0].remainingAmount).to.equal(4000);
  // 10% fee
  expect(await tether.balanceOf(abcSale.address)).to.equal((6000 + 4000) * 2);

  console.log("Investor2 investing int XYZ Sale with approval");
  // using hardcoded numbers here to simplicity
  transaction = await tether.connect(investor2).approve(xyzSale.address, 20000 * 1 * 1.1);
  await transaction.wait();
  transaction = await xyzSale.connect(xyzOwner).approveInvestor(investor2.address, 20000);
  await transaction.wait();
  transaction = await xyzSale.connect(investor2).invest(20000);
  await transaction.wait();
  expect(await saNFT.balanceOf(investor2.address)).to.equal(1);
  saId = await saNFT.tokenOfOwnerByIndex(investor2.address, 0);
  sa = await saNFT.getSA(saId);
  expect(await sa.subSAs[0].sale).to.equal(xyzSale.address);
  // 5% fee
  expect(await sa.subSAs[0].remainingAmount).to.equal(20000)
  // 10% fee
  expect(await tether.balanceOf(xyzSale.address)).to.equal(20000 * 1);

  console.log("Checking Ape Owner for investing fee");
  expect(await saNFT.balanceOf(apeOwner.address)).to.equal(3);
  nft = saNFT.tokenOfOwnerByIndex(apeOwner.address, 0);
  sa = await saNFT.getSA(nft);
  expect(sa.subSAs[0].sale).to.equal(abcSale.address);
  expect(sa.subSAs[0].remainingAmount).to.equal(300);
  nft = saNFT.tokenOfOwnerByIndex(apeOwner.address, 1);
  sa = await saNFT.getSA(nft);
  expect(sa.subSAs[0].sale).to.equal(abcSale.address);
  expect(sa.subSAs[0].remainingAmount).to.equal(200);
  sa = await saNFT.getSA(saNFT.tokenOfOwnerByIndex(apeOwner.address, 2));
  expect(sa.subSAs[0].sale).to.equal(xyzSale.address);
  expect(sa.subSAs[0].remainingAmount).to.equal(1000);
  expect(await tether.balanceOf(apeOwner.address)).to.equal(4000);

  console.log("Splitting investor 2's nft");
  // before split
  nft = saNFT.tokenOfOwnerByIndex(investor2.address, 0);
  sa = await saNFT.getSA(nft);
  expect(sa.subSAs[0].remainingAmount).to.equal(20000);
  // do the split
  keptAmounts = [8000];
  transaction = await tether.connect(investor2).approve(saNFT.address, 100);
  await transaction.wait();
  transaction = await saNFT.connect(investor2).split(nft, keptAmounts);
  await transaction.wait();
  expect(await saNFT.balanceOf(investor2.address)).to.equal(2);
  nft = await saNFT.tokenOfOwnerByIndex(investor2.address, 0);
  sa = await saNFT.getSA(nft);
  expect(sa.subSAs[0].sale).to.equal(xyzSale.address);
  expect(sa.subSAs[0].remainingAmount).to.equal(8000);
  nft = await saNFT.tokenOfOwnerByIndex(investor2.address, 1);
  sa = await saNFT.getSA(nft);
  expect(sa.subSAs[0].sale).to.equal(xyzSale.address);
  expect(sa.subSAs[0].remainingAmount).to.equal(12000);
  // check for 100 fee collected
  expect(await tether.balanceOf(apeOwner.address)).to.equal(4100);

  console.log("Transfer one of investor2 nft to investor1");
  expect(await saNFT.balanceOf(investor2.address)).to.equal(2);
  expect(await saNFT.balanceOf(investor1.address)).to.equal(2);
  nft = await saNFT.tokenOfOwnerByIndex(investor2.address, 0);
  transaction = await tether.connect(investor2).approve(saNFT.address, 100);
  await transaction.wait();
  transaction = await saNFT.connect(investor2).transferFrom(investor2.address, investor1.address, nft);
  await transaction.wait();
  expect(await saNFT.balanceOf(investor2.address)).to.equal(1);
  expect(await saNFT.balanceOf(investor1.address)).to.equal(3);
  expect(await tether.balanceOf(apeOwner.address)).to.equal(4200);

  console.log("Merge investor1's nft");
  expect(await saNFT.balanceOf(investor1.address)).to.equal(3);
  nft0 = saNFT.tokenOfOwnerByIndex(investor1.address, 0);
  nft1 = saNFT.tokenOfOwnerByIndex(investor1.address, 1);
  nft2 = saNFT.tokenOfOwnerByIndex(investor1.address, 2);
  transaction = await tether.connect(investor1).approve(saNFT.address, 100);
  await transaction.wait();
  transaction = await saNFT.connect(investor1).merge([nft0, nft1, nft2]);
  await transaction.wait();
  expect(await saNFT.balanceOf(investor1.address)).to.equal(1);
  expect(await tether.balanceOf(apeOwner.address)).to.equal(4300);
  nft = await saNFT.tokenOfOwnerByIndex(investor1.address, 0);
  sa = await saNFT.getSA(nft);
  expect(sa.subSAs.length).to.equal(2);
  expect(sa.subSAs[0].sale).to.equal(abcSale.address);
  expect(sa.subSAs[0].remainingAmount).to.equal(10000);
  expect(sa.subSAs[1].sale).to.equal(xyzSale.address);
  expect(sa.subSAs[1].remainingAmount).to.equal(8000);
  expect(await tether.balanceOf(apeOwner.address)).to.equal(4300);

  let currentBlockTimeStamp;
  console.log("Vesting NFT of investor1 after first mile stone");
  // list tokens
  transaction = await abcSale.connect(abcOwner).triggerTokenListing();
  await transaction.wait();
  transaction = await xyzSale.connect(xyzOwner).triggerTokenListing();
  await transaction.wait();

  // before vesting
  nft = saNFT.tokenOfOwnerByIndex(investor1.address, 0);
  sa = await saNFT.getSA(nft);
  expect(await abc.balanceOf(investor1.address)).to.equal(0);
  expect(sa.subSAs[0].remainingAmount).to.equal(10000);

  // move forward in time
  currentBlockTimeStamp = (await abcSale.currentBlockTimeStamp()).toNumber();
  await ethers.provider.send("evm_setNextBlockTimestamp", [currentBlockTimeStamp + 20]);

  transaction = await saNFT.connect(investor1).vest(nft);
  await transaction.wait();
  sa = await saNFT.getSA(nft);
  expect(await abc.balanceOf(investor1.address)).to.equal(5000);
  expect(sa.subSAs[0].remainingAmount).to.equal(5000);
  expect(await xyz.balanceOf(investor1.address)).to.equal(4000);
  expect(sa.subSAs[1].remainingAmount).to.equal(4000);

  console.log("Vesting NFT 1 of investor1 after second mile stone");
  expect(await saNFT.balanceOf(investor1.address)).to.equal(1);
  nft = saNFT.tokenOfOwnerByIndex(investor1.address, 0);
  network = await ethers.provider.getNetwork();
  await ethers.provider.send("evm_setNextBlockTimestamp", [currentBlockTimeStamp + 1020]);

  await saNFT.connect(investor1).vest(nft);

  expect(await abc.balanceOf(investor1.address)).to.equal(10000);
  expect(await xyz.balanceOf(investor1.address)).to.equal(8000);
  // SAs should have been burned
  expect(await saNFT.balanceOf(investor1.address)).to.equal(0);

  console.log("Withdraw payment from sale");
  await expect(abcSale.withdrawPayment(20000)).to.be.revertedWith("Caller is not sale owner");
  console.log("balance is", (await tether.balanceOf(abcSale.address)).toNumber());
  await abcSale.connect(abcOwner).withdrawPayment(20000)

  console.log("Withdraw token from sale");
  });
})