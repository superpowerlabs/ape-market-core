const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle} = require('./helpers')

// const delay = ms => new Promise(res => setTimeout(res, ms));

const saleJson = require('../src/artifacts/contracts/sale/Sale.sol/Sale.json')

describe.only("Integration Test", function() {

  let ERC20Token
  let abc
  let xyz
  let Tether
  let tether
  let SAStorage
  let storage
  let SAToken
  let satoken
  let SaleFactory
  let factory
  let abcSale
  let xyzSale
  let SAManager
  let manager

  let saleSetup
  let saleVestingSchedule

  let owner, factoryAdmin, tetherOwner, abcOwner, xyzOwner, investor1, investor2, apeWallet
  let addr0 = '0x0000000000000000000000000000000000000000'

  let timestamp
  let chainId

  before(async function () {
    [owner, factoryAdmin, tetherOwner, abcOwner, xyzOwner, investor1, investor2, apeWallet] = await ethers.getSigners()
  })

  async function getTimestamp() {
    return (await ethers.provider.getBlock()).timestamp
  }

  async function initNetworkAndDeploy() {

    SAStorage = await ethers.getContractFactory("SAStorage")
    storage = await SAStorage.deploy()
    await storage.deployed()

    SaleFactory = await ethers.getContractFactory("SaleFactory")
    factory = await SaleFactory.deploy()
    await factory.deployed()
    factory.grantLevel(await factory.FACTORY_ADMIN_LEVEL(), factoryAdmin.address)

    SAToken = await ethers.getContractFactory("SAToken")
    satoken = await SAToken.deploy(factory.address, storage.address)
    await satoken.deployed()

    await storage.grantLevel(await storage.MANAGER_LEVEL(), satoken.address)

    ERC20Token = await ethers.getContractFactory("ERC20Token")
    abc = await ERC20Token.connect(abcOwner).deploy("Abc Token", "ABC")
    await abc.deployed()
    xyz = await ERC20Token.connect(xyzOwner).deploy("XYZ", "XYZ");
    await xyz.deployed();

    Tether = await ethers.getContractFactory("TetherMock")
    tether = await Tether.connect(tetherOwner).deploy()
    await tether.deployed()

    SAManager = await ethers.getContractFactory("SAManager")
    manager = await SAManager.deploy(satoken.address, storage.address, tether.address, 100, apeWallet.address)
    await manager.deployed()

    await satoken.grantLevel(await satoken.MANAGER_LEVEL(), manager.address)
    await storage.grantLevel(await storage.MANAGER_LEVEL(), manager.address)
  }

  describe('Full flow', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the entire process works", async function () {

      console.log('Fund investors')
      await (await tether.connect(tetherOwner).transfer(investor1.address, 40000))
      expect(await tether.balanceOf(investor1.address)).to.equal(40000);
      await (await tether.connect(tetherOwner).transfer(investor2.address, 50000))
      expect(await tether.balanceOf(investor2.address)).to.equal(50000);

      // create sales

      saleSetup = {
        satoken: satoken.address,
        minAmount: 100,
        capAmount: 20000,
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
      saleVestingSchedule = [
        {
          timestamp: 10,
          percentage: 50
        },
        {
          timestamp: 1000,
          percentage: 100
        }]

      console.log('Deploy new sale for ABC')
      await factory.connect(factoryAdmin).newSale(saleSetup,saleVestingSchedule, apeWallet.address)
      let saleAddress = await factory.lastSale()

      abcSale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
      expect(await abcSale.levels(saleSetup.owner)).to.equal(await abcSale.SALE_OWNER_LEVEL())
      const [setup, steps] = await abcSale.getSetup()
      expect(setup.owner).to.equal(abcOwner.address)

      console.log('Launching ABC Sale')
      await abc.connect(abcOwner).approve(abcSale.address, setup.capAmount * 1.05)
      await abcSale.connect(abcOwner).launch()
      expect(await abc.balanceOf(abcSale.address)).to.equal(setup.capAmount * 1.05);

      saleSetup.owner = xyzOwner.address;
      saleSetup.sellingToken = xyz.address;
      saleSetup.pricingPayment = 1;

      console.log('Deploy new sale for XYZ')
      await factory.connect(factoryAdmin).newSale(saleSetup,saleVestingSchedule, apeWallet.address)
      saleAddress = await factory.lastSale()
      xyzSale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)

      console.log("Launching XYZ Sale");
      await xyz.connect(xyzOwner).approve(xyzSale.address, setup.capAmount * 1.05);
      await xyzSale.connect(xyzOwner).launch()
      expect(await xyz.balanceOf(xyzSale.address)).to.equal(setup.capAmount * 1.05);


      console.log("Investor1 investing in ABC Sale without approval");
      // using hardcoded numbers here to simplicity
      await tether.connect(investor1).approve(abcSale.address, 10000 * 2 * 1.1);
      await expect(abcSale.connect(investor1).invest(10000)).to.be.revertedWith("Sale: Amount if above approved amount");

      console.log("Investor1 investing in ABC Sale with approval");
      // using hardcoded numbers here to simplicity
      await abcSale.connect(abcOwner).approveInvestor(investor1.address, 10000);
      await abcSale.connect(investor1).invest(6000);
      expect(await satoken.balanceOf(investor1.address)).to.equal(1);
      let saId = await satoken.tokenOfOwnerByIndex(investor1.address, 0);
      let bundle = await storage.getBundle(saId);
      expect(await bundle.sas[0].sale).to.equal(abcSale.address);
      // 5% fee
      expect(await bundle.sas[0].remainingAmount).to.equal(6000);
      // 10% fee
      expect(await tether.balanceOf(abcSale.address)).to.equal(6000 * 2);


      console.log("Investor1 investing in ABC Sale with approval again");
      // using hardcoded numbers here to simplicity
      await abcSale.connect(investor1).invest(4000);
      expect(await satoken.balanceOf(investor1.address)).to.equal(2);
      saId = await satoken.tokenOfOwnerByIndex(investor1.address, 1);
      bundle = await storage.getBundle(saId);
      expect(await bundle.sas[0].sale).to.equal(abcSale.address);
      // 5% fee
      expect(await bundle.sas[0].remainingAmount).to.equal(4000);
      // 10% fee
      expect(await tether.balanceOf(abcSale.address)).to.equal((6000 + 4000) * 2);


      console.log("Investor2 investing int XYZ Sale with approval");
      // using hardcoded numbers here to simplicity
      await tether.connect(investor2).approve(xyzSale.address, 20000 * 1.1);
      await xyzSale.connect(xyzOwner).approveInvestor(investor2.address, 20000);
      await xyzSale.connect(investor2).invest(20000);
      expect(await satoken.balanceOf(investor2.address)).to.equal(1);
      saId = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      bundle = await storage.getBundle(saId);
      expect(await bundle.sas[0].sale).to.equal(xyzSale.address);
      // 5% fee
      expect(await bundle.sas[0].remainingAmount).to.equal(20000)
      // 10% fee
      expect(await tether.balanceOf(xyzSale.address)).to.equal(20000);


      console.log("Checking Ape Owner for investing fee");
      expect(await satoken.balanceOf(apeWallet.address)).to.equal(3);
      nft = satoken.tokenOfOwnerByIndex(apeWallet.address, 0);
      bundle = await storage.getBundle(nft);
      expect(bundle.sas[0].sale).to.equal(abcSale.address);
      expect(bundle.sas[0].remainingAmount).to.equal(300);
      nft = satoken.tokenOfOwnerByIndex(apeWallet.address, 1);
      bundle = await storage.getBundle(nft);
      expect(bundle.sas[0].sale).to.equal(abcSale.address);
      expect(bundle.sas[0].remainingAmount).to.equal(200);
      bundle = await storage.getBundle(satoken.tokenOfOwnerByIndex(apeWallet.address, 2));
      expect(bundle.sas[0].sale).to.equal(xyzSale.address);
      expect(bundle.sas[0].remainingAmount).to.equal(1000);
      expect(await tether.balanceOf(apeWallet.address)).to.equal(4000);

      console.log("Splitting investor 2's nft");
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      bundle = await storage.getBundle(nft);
      expect(bundle.sas[0].remainingAmount).to.equal(20000);
      // do the split
      keptAmounts = [8000];
      await tether.connect(investor2).approve(manager.address, 100);
      await manager.connect(investor2).split(nft, keptAmounts, false);
      expect(await satoken.balanceOf(investor2.address)).to.equal(2);
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      bundle = await storage.getBundle(nft);
      expect(bundle.sas[0].sale).to.equal(xyzSale.address);
      expect(bundle.sas[0].remainingAmount).to.equal(8000);
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 1);

      bundle = await storage.getBundle(nft);
      expect(bundle.sas[0].sale).to.equal(xyzSale.address);
      expect(bundle.sas[0].remainingAmount).to.equal(12000);
      // check for 100 fee collected
      expect(await tether.balanceOf(apeWallet.address)).to.equal(4100);


      console.log("Transfer one of investor2 nft to investor1");
      expect(await satoken.balanceOf(investor2.address)).to.equal(2);
      expect(await satoken.balanceOf(investor1.address)).to.equal(2);
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      await tether.connect(investor2).approve(manager.address, 100)
      await satoken.connect(investor2).transferFrom(investor2.address, investor1.address, nft)
      expect(await satoken.balanceOf(investor2.address)).to.equal(1);
      expect(await satoken.balanceOf(investor1.address)).to.equal(3);
      expect(await tether.balanceOf(apeWallet.address)).to.equal(4100);

      console.log("Merge investor1's nft");
      expect(await satoken.balanceOf(investor1.address)).to.equal(3);
      nft0 = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      nft1 = satoken.tokenOfOwnerByIndex(investor1.address, 1);
      nft2 = satoken.tokenOfOwnerByIndex(investor1.address, 2);
      await tether.connect(investor1).approve(manager.address, 100);
      await manager.connect(investor1).merge([nft0, nft1, nft2], false);
      expect(await satoken.balanceOf(investor1.address)).to.equal(1);
      expect(await tether.balanceOf(apeWallet.address)).to.equal(4200);
      nft = await satoken.tokenOfOwnerByIndex(investor1.address, 0);
      bundle = await storage.getBundle(nft);
      expect(bundle.sas.length).to.equal(2);
      expect(bundle.sas[0].sale).to.equal(abcSale.address);
      expect(bundle.sas[0].remainingAmount).to.equal(10000);
      expect(bundle.sas[1].sale).to.equal(xyzSale.address);
      expect(bundle.sas[1].remainingAmount).to.equal(8000);
      expect(await tether.balanceOf(apeWallet.address)).to.equal(4200);

      let currentBlockTimeStamp;
      console.log("Vesting NFT of investor1 after first mile stone");
      // list tokens
      transaction = await abcSale.connect(abcOwner).triggerTokenListing();
      await transaction.wait();
      transaction = await xyzSale.connect(xyzOwner).triggerTokenListing();
      await transaction.wait();

      // before vesting
      nft = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      bundle = await storage.getBundle(nft);
      expect(await abc.balanceOf(investor1.address)).to.equal(0);
      expect(bundle.sas[0].remainingAmount).to.equal(10000);

      // move forward in time
      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp() + 20]);

      await satoken.connect(investor1).vest(nft);
      bundle = await storage.getBundle(nft);
      expect(await abc.balanceOf(investor1.address)).to.equal(5000);
      expect(bundle.sas[0].remainingAmount).to.equal(5000);
      expect(await xyz.balanceOf(investor1.address)).to.equal(4000);
      expect(bundle.sas[1].remainingAmount).to.equal(4000);

      console.log("Vesting NFT 1 of investor1 after second mile stone");
      expect(await satoken.balanceOf(investor1.address)).to.equal(1);
      nft = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      network = await ethers.provider.getNetwork();

      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp() + 1020]);

      await satoken.connect(investor1).vest(nft);

      expect(await abc.balanceOf(investor1.address)).to.equal(10000);
      expect(await xyz.balanceOf(investor1.address)).to.equal(8000);
      // SAs should have been burned

      expect(await satoken.balanceOf(investor1.address)).to.equal(0);

      console.log("Withdraw payment from sale");
      await assertThrowsMessage(
          abcSale.connect(xyzOwner).withdrawPayment(20000),
          "Sale: caller is not the owner"
      )

      console.log("balance is", (await tether.balanceOf(abcSale.address)).toNumber());
      await abcSale.connect(abcOwner).withdrawPayment(20000)

      console.log("Withdraw token from sale");

    })


  })


})