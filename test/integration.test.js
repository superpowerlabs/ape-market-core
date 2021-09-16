const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle, getTimestamp} = require('./helpers')

// const delay = ms => new Promise(res => setTimeout(res, ms));

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe.skip("Integration Test", function () {

  let Profile
  let profile
  let ERC20Token
  let abc
  let xyz
  let Tether
  let tether
  let SANFT
  let satoken
  let SaleFactory
  let factory
  let SANFTManager
  let tokenExtras
  let SaleData
  let saleData


  let saleSetup
  let saleVestingSchedule

  let owner, validator, factoryAdmin, tetherOwner, abcOwner, xyzOwner, investor1, investor2, apeWallet
  let addr0 = '0x0000000000000000000000000000000000000000'

  async function getSignatureByValidator(saleId, setup, schedule) {
    const hash = await factory.encodeForSignature(saleId, setup, schedule)
    const signingKey = new ethers.utils.SigningKey('0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d')
    const signedDigest = signingKey.signDigest(hash)
    return ethers.utils.joinSignature(signedDigest)
  }

  function CL() {
    let str = ''
    for (let s of arguments) {
      str += s + ' '
    }
    console.log(str)
  }

  before(async function () {
    [owner, validator, factoryAdmin, tetherOwner, abcOwner, xyzOwner, investor1, investor2, apeWallet] = await ethers.getSigners()
  })

  async function getSale(saleSetup, saleVestingSchedule) {
    let saleId = await saleDB.nextSaleId()
    let signature = getSignatureByValidator(saleId, saleSetup, saleVestingSchedule)
    await factory.connect(factoryAdmin).approveSale(saleId)
    await factory.connect(factoryAdmin).newSale(saleId, saleSetup, saleVestingSchedule, signature)
    let saleAddress = await saleDB.getSaleAddressById(saleId)
    return [new ethers.Contract(saleAddress, saleJson.abi, ethers.provider), saleId.toNumber()]
  }

  async function initNetworkAndDeploy() {

    Profile = await ethers.getContractFactory("Profile")
    profile = await Profile.deploy()
    await profile.deployed()

    SaleData = await ethers.getContractFactory("SaleData")
    saleData = await SaleData.deploy(apeWallet.address)
    await saleData.deployed()

    SaleFactory = await ethers.getContractFactory("SaleFactory")
    factory = await SaleFactory.deploy(saleData.address, validator.address)
    await factory.deployed()
    await saleData.grantLevel(await saleData.ADMIN_LEVEL(), factory.address)
    await factory.grantLevel(await factory.OPERATOR_LEVEL(), factoryAdmin.address)

    SANFTManager = await ethers.getContractFactory("SANFTManager")
    tokenExtras = await SANFTManager.deploy(profile.address)
    await tokenExtras.deployed()

    SANFT = await ethers.getContractFactory("SANFT")
    satoken = await SANFT.deploy(factory.address, tokenExtras.address)
    await satoken.deployed()
    await tokenExtras.setToken(satoken.address)

    ERC20Token = await ethers.getContractFactory("ERC20Token")
    abc = await ERC20Token.connect(abcOwner).deploy("Abc Token", "ABC")
    await abc.deployed()
    xyz = await ERC20Token.connect(xyzOwner).deploy("XYZ", "XYZ");
    await xyz.deployed();

    Tether = await ethers.getContractFactory("TetherMock")
    tether = await Tether.connect(tetherOwner).deploy()
    await tether.deployed()

    await satoken.setupUpPayments(tether.address, 100, apeWallet.address)
  }

  function normalize(amount) {
    return '' + amount + '0'.repeat(18);
  }

  function normalizeMinMaxAmount (amount) {
    return '' + amount + '0'.repeat(15);
  }

  describe('Full flow', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the entire process works", async function () {

      CL('Fund investors')
      await (await tether.connect(tetherOwner).transfer(investor1.address, normalize(40000)))
      expect(await tether.balanceOf(investor1.address)).equal(normalize(40000));
      await (await tether.connect(tetherOwner).transfer(investor2.address, normalize(50000)))
      expect(await tether.balanceOf(investor2.address)).equal(normalize(50000));

      // create sales

      saleSetup = {
        satoken: satoken.address,
        sellingToken: abc.address,
        paymentToken: tether.address,
        owner: abcOwner.address,
        remainingAmount: 0,
        minAmount: 100000,
        capAmount: 20000000,
        pricingToken: 1,
        pricingPayment: 2,
        tokenListTimestamp: 0,
        tokenFeePoints: 500,
        paymentFeePoints: 1000,
        isTokenTransferable: true
      };
      saleVestingSchedule = [
        {
          waitTime: 10,
          percentage: 50
        },
        {
          waitTime: 999,
          percentage: 100
        }]

      CL('Deploy new sale for ABC')
      const [abcSale, abcSaleId] = await getSale(saleSetup, saleVestingSchedule)

      const setup = await saleData.getSetupById(abcSaleId)
      expect(setup.owner).equal(abcOwner.address)

      CL('Launching ABC Sale')
      await abc.connect(abcOwner).approve(abcSale.address, normalizeMinMaxAmount(setup.capAmount * 1.05))

      await abcSale.connect(abcOwner).launch()
      expect(await abc.balanceOf(abcSale.address)).equal(normalizeMinMaxAmount(setup.capAmount * 1.05));

      saleSetup.owner = xyzOwner.address;
      saleSetup.sellingToken = xyz.address;
      saleSetup.pricingPayment = 1;

      CL('Deploy new sale for XYZ')
      const [xyzSale, xyzSaleId] = await getSale(saleSetup, saleVestingSchedule)

      CL("Launching XYZ Sale");
      await xyz.connect(xyzOwner).approve(xyzSale.address, normalizeMinMaxAmount(setup.capAmount * 1.05));
      await xyzSale.connect(xyzOwner).launch()
      expect(await xyz.balanceOf(xyzSale.address)).equal(normalizeMinMaxAmount(setup.capAmount * 1.05));

      CL("Investor1 investing in ABC Sale without approval");
      // using hardcoded numbers here to simplicity
      await tether.connect(investor1).approve(abcSale.address, normalize(10000 * 2 * 1.1));
      await expect(abcSale.connect(investor1).invest(normalize(10000))).revertedWith("Sale: Amount if above approved amount");

      CL("Investor1 investing in ABC Sale with approval");
      // using hardcoded numbers here to simplicity
      await saleData.connect(abcOwner).approveInvestor(abcSaleId, investor1.address, normalize(10000));
      await abcSale.connect(investor1).invest(normalize(6000));
      expect(await satoken.balanceOf(investor1.address)).equal(1);
      let saId = await satoken.tokenOfOwnerByIndex(investor1.address, 0);
      let bundle = await satoken.getBundle(saId);
      expect(await bundle.sas[0].sale).equal(abcSale.address);
      // 5% fee
      expect(await bundle.sas[0].remainingAmount).equal(normalize(6000));
      // 10% fee
      expect(await tether.balanceOf(abcSale.address)).equal(normalize(6000 * 2));


      CL("Investor1 investing in ABC Sale with approval again");
      // using hardcoded numbers here to simplicity
      await abcSale.connect(investor1).invest(normalize(4000));
      expect(await satoken.balanceOf(investor1.address)).equal(2);
      saId = await satoken.tokenOfOwnerByIndex(investor1.address, 1);
      bundle = await satoken.getBundle(saId);
      expect(await bundle.sas[0].sale).equal(abcSale.address);
      // 5% fee
      expect(await bundle.sas[0].remainingAmount).equal(normalize(4000));
      // 10% fee
      expect(await tether.balanceOf(abcSale.address)).equal(normalize((6000 + 4000) * 2));


      CL("Investor2 investing int XYZ Sale with approval");
      // using hardcoded numbers here to simplicity
      await tether.connect(investor2).approve(xyzSale.address, normalize(20000 * 1.1));
      await saleData.connect(xyzOwner).approveInvestor(xyzSaleId, investor2.address, normalize(20000));
      await xyzSale.connect(investor2).invest(normalize(20000));
      expect(await satoken.balanceOf(investor2.address)).equal(1);
      saId = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      bundle = await satoken.getBundle(saId);
      expect(await bundle.sas[0].sale).equal(xyzSale.address);
      // 5% fee
      expect(await bundle.sas[0].remainingAmount).equal(normalize(20000))
      // 10% fee
      expect(await tether.balanceOf(xyzSale.address)).equal(normalize(20000));


      CL("Checking Ape Owner for investing fee");
      expect(await satoken.balanceOf(apeWallet.address)).equal(3);
      let nft = satoken.tokenOfOwnerByIndex(apeWallet.address, 0);
      bundle = await satoken.getBundle(nft);
      expect(bundle.sas[0].sale).equal(abcSale.address);
      expect(bundle.sas[0].remainingAmount).equal(normalize(300));
      nft = satoken.tokenOfOwnerByIndex(apeWallet.address, 1);
      bundle = await satoken.getBundle(nft);
      expect(bundle.sas[0].sale).equal(abcSale.address);
      expect(bundle.sas[0].remainingAmount).equal(normalize(200));
      bundle = await satoken.getBundle(satoken.tokenOfOwnerByIndex(apeWallet.address, 2));
      expect(bundle.sas[0].sale).equal(xyzSale.address);
      expect(bundle.sas[0].remainingAmount).equal(normalize(1000));
      expect(await tether.balanceOf(apeWallet.address)).equal(normalize(4000));

      CL("Splitting investor 2's nft");
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      bundle = await satoken.getBundle(nft);
      expect(bundle.sas[0].remainingAmount).equal(normalize(20000));
      // do the split
      let keptAmounts = [normalize(8000)];
      await tether.connect(investor2).approve(satoken.address, normalize(100));
      await satoken.connect(investor2).split(nft, keptAmounts);
      expect(await satoken.balanceOf(investor2.address)).equal(2);
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      // CL('nft', nft.toNumber()) // 7
      bundle = await satoken.getBundle(nft);
      CL(xyzSale.address)
      expect(bundle.sas[0].sale).equal(xyzSale.address);
      expect(bundle.sas[0].remainingAmount).equal(normalize(8000));
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 1);
      // CL('nft', nft.toNumber()) // 6

      bundle = await satoken.getBundle(nft);
      expect(bundle.sas[0].sale).equal(xyzSale.address);
      expect(bundle.sas[0].remainingAmount).equal(normalize(12000));
      // check for 100 fee collected
      expect(await tether.balanceOf(apeWallet.address)).equal(normalize(4100));


      CL("Transfer one of investor2 nft to investor1");
      expect(await satoken.balanceOf(investor2.address)).equal(2);
      expect(await satoken.balanceOf(investor1.address)).equal(2);
      nft = await satoken.tokenOfOwnerByIndex(investor2.address, 0);
      await tether.connect(investor2).approve(satoken.address, normalize(100))
      await satoken.connect(investor2).transferFrom(investor2.address, investor1.address, nft)
      expect(await satoken.balanceOf(investor2.address)).equal(1);
      expect(await satoken.balanceOf(investor1.address)).equal(3);
      expect(await tether.balanceOf(apeWallet.address)).equal(normalize(4100));

      CL("Merge investor1's nft");
      expect(await satoken.balanceOf(investor1.address)).equal(3);
      let nft0 = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      let nft1 = satoken.tokenOfOwnerByIndex(investor1.address, 1);
      let nft2 = satoken.tokenOfOwnerByIndex(investor1.address, 2);
      await tether.connect(investor1).approve(satoken.address, normalize(100));
      await satoken.connect(investor1).merge([nft0, nft1, nft2]);
      expect(await satoken.balanceOf(investor1.address)).equal(1);
      expect(await tether.balanceOf(apeWallet.address)).equal(normalize(4200));
      nft = await satoken.tokenOfOwnerByIndex(investor1.address, 0);
      bundle = await satoken.getBundle(nft);
      expect(bundle.sas.length).equal(2);
      expect(bundle.sas[0].sale).equal(abcSale.address);
      expect(bundle.sas[0].remainingAmount).equal(normalize(10000));
      expect(bundle.sas[1].sale).equal(xyzSale.address);
      expect(bundle.sas[1].remainingAmount).equal(normalize(8000));
      expect(await tether.balanceOf(apeWallet.address)).equal(normalize(4200));

      let currentBlockTimeStamp;
      CL("Vesting NFT of investor1 after first mile stone");
      // list tokens
      await saleData.connect(abcOwner).triggerTokenListing(abcSaleId);
      await saleData.connect(xyzOwner).triggerTokenListing(xyzSaleId);

      // before vesting
      nft = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      bundle = await satoken.getBundle(nft);
      expect(await abc.balanceOf(investor1.address)).equal(0);
      expect(bundle.sas[0].remainingAmount).equal(normalize(10000));

      // move forward in time
      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 20]);

      await satoken.connect(investor1).vest(nft);
      nft = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      bundle = await satoken.getBundle(nft);
      expect(await abc.balanceOf(investor1.address)).equal(normalize(5000));
      expect(bundle.sas[0].remainingAmount).equal(normalize(5000));
      expect(await xyz.balanceOf(investor1.address)).equal(normalize(4000));
      expect(bundle.sas[1].remainingAmount).equal(normalize(4000));

      CL("Vesting NFT 1 of investor1 after second mile stone");
      expect(await satoken.balanceOf(investor1.address)).equal(1);
      nft = satoken.tokenOfOwnerByIndex(investor1.address, 0);
      network = await ethers.provider.getNetwork();

      await ethers.provider.send("evm_setNextBlockTimestamp", [await getTimestamp(ethers) + 1020]);

      await satoken.connect(investor1).vest(nft);
      expect(await abc.balanceOf(investor1.address)).equal(normalize(10000));
      expect(await xyz.balanceOf(investor1.address)).equal(normalize(8000));
      // SAs should have been burned

      expect(await satoken.balanceOf(investor1.address)).equal(0);

      CL("Withdraw payment from sale");
      await expect(abcSale.connect(xyzOwner).withdrawPayment(normalize(20000))).revertedWith("Sale: caller is not the owner");

      CL("balance is", (await tether.balanceOf(abcSale.address)).toString());
      await abcSale.connect(abcOwner).withdrawPayment(normalize(20000))

      CL("Withdraw token from sale");

    })


  })


})
