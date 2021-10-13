const {expect, assert} = require("chai")
const DeployUtils = require('../scripts/lib/DeployUtils')

// const delay = ms => new Promise(res => setTimeout(res, ms));

const saleJson = require('../artifacts/contracts/sale/Sale.sol/Sale.json')

describe("Integration Test", function () {

  let Profile
  let profile
  let ERC20Token
  let abc
  let xyz
  let Tether
  let tether
  let SANFT
  let sANFT
  let SaleFactory
  let factory
  let SANFTManager
  let tokenExtras
  let SaleData
  let saleData
  let saleSetup
  let saleVestingSchedule

  let owner, operator, tetherOwner, abcOwner, xyzOwner, buyer, buyer1, apeWallet
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
    [owner, validator, operator, apeWallet, seller, buyer, buyer2] = await ethers.getSigners()
  })

  const deployUtils = new DeployUtils(ethers)

  async function initNetworkAndDeploy() {

   const results = await deployUtils.initAndDeploy({
      apeWallet: apeWallet.address,
      operators: [operator.address]
    })

    apeRegistry = results.apeRegistry
    profile = results.profile
    saleSetupHasher = results.saleSetupHasher
    saleData = results.saleData
    saleDB = results.saleDB
    saleFactory = results.saleFactory
    sANFT = results.sANFT
    sANFTManager = results.sANFTManager
    tokenRegistry = results.tokenRegistry
    tether = results.uSDT
  }

  function normalize(val, n = 18) {
    return '' + val + '0'.repeat(n)
  }

  describe('Full flow', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that the entire process works", async function () {

      CL('Fund investors')
      await (await tether.transfer(buyer.address, normalize(40000, 6))).wait()
      await (await tether.transfer(buyer2.address, normalize(50000, 6))).wait()

      CL('Deploy ABC Token')
      sellingToken = await deployUtils.deployContractBy("ERC20Token", seller, "Abc Token", "ABC")

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

    CL('validateAndPackVestingSteps')
    let [schedule, msg] = await saleSetupHasher.validateAndPackVestingSteps(saleVestingSchedule)

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
      saleAddress: addr0,
      isFutureToken: false,
      futureTokenSaleId: 0,
    };

    CL('packAndHashSaleConfiguration')
    hash = await saleSetupHasher.packAndHashSaleConfiguration(saleSetup, [], tether.address)

    CL("Approve Sale")
    transaction = await saleFactory.connect(operator).approveSale(hash)
    await transaction.wait()

    saleId = await saleFactory.getSaleIdBySetupHash(hash)

    await expect(saleFactory.connect(seller).newSale(saleId, saleSetup, [], tether.address))
        .emit(saleFactory, "NewSale")
    saleAddress = await saleDB.getSaleAddressById(saleId)
    abcSale = new ethers.Contract(saleAddress, saleJson.abi, ethers.provider)
    assert.isTrue(await saleDB.getSaleIdByAddress(saleAddress) > 0)

    CL("Launch abcSale")
    await sellingToken.connect(seller).approve(saleAddress, await saleData.fromValueToTokensAmount(saleId, saleSetup.totalValue * 1.05))
    await abcSale.connect(seller).launch()

    CL("Buyer investing in ABC Sale without approval");
    // using hardcoded numbers here to simplicity
    await tether.connect(buyer).approve(abcSale.address, normalize(10000 * 1.1, 6));
    await expect(abcSale.connect(buyer).invest(10000)).revertedWith("SaleData: Amount is above approved amount");

    CL("Buyer investing in ABC Sale with approval");
    // using hardcoded numbers here to simplicity
    await saleData.connect(seller).approveInvestors(saleId, [buyer.address], [10000]);
    await abcSale.connect(buyer).invest(6000);
    expect(await sANFT.balanceOf(buyer.address)).equal(1);
    let saId = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    let bundle = await sANFT.getBundle(saId);
    expect(await bundle[0].saleId).equal(saleId);
    CL("Checking token balance");
    expect(await bundle[0].fullAmount).equal(normalize(3000));
    CL("Check Tether balance");
    expect(await tether.balanceOf(abcSale.address)).equal(normalize(6000, 6));

    CL("buyer investing in ABC Sale with approval again");
    // using hardcoded numbers here to simplicity
    await abcSale.connect(buyer).invest(4000);
    expect(await sANFT.balanceOf(buyer.address)).equal(2);
    saId = await sANFT.tokenOfOwnerByIndex(buyer.address, 1);
    bundle = await sANFT.getBundle(saId);
    expect(bundle[0].saleId).equal(saleId);
    expect(bundle[0].fullAmount).equal(normalize(2000));
    expect(await tether.balanceOf(abcSale.address)).equal(normalize(6000 + 4000, 6));


    CL("Checking Ape Owner for investing fee");
    expect(await sANFT.balanceOf(apeWallet.address)).equal(1);
    let nft = sANFT.tokenOfOwnerByIndex(apeWallet.address, 0);
    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].saleId).equal(saleId);
    expect(bundle[0].fullAmount).equal(normalize(1250));
    expect(await tether.balanceOf(apeWallet.address)).equal(normalize(300, 6));


    CL("Splitting buyer's nft");
    nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].fullAmount).equal(normalize(3000));

    let keptAmounts = [normalize(1000)];
    await sANFTManager.connect(buyer).split(nft, keptAmounts);
    expect(await sANFT.balanceOf(buyer.address)).equal(3);
    nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);

    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].saleId).equal(saleId);
    expect(bundle[0].remainingAmount).equal(normalize(1000));

    nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 2);
    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].remainingAmount).equal(normalize(1970));

    CL("Checking for split fee");
    expect(await sANFT.balanceOf(apeWallet.address)).equal(2);
    nft = await sANFT.tokenOfOwnerByIndex(apeWallet.address, 1);
    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].remainingAmount).equal(normalize(30));


    CL("Merge buyer's nft");
    expect(await sANFT.balanceOf(buyer.address)).equal(3);
    let nft0 = sANFT.tokenOfOwnerByIndex(buyer.address, 0);  // 1000
    let nft1 = sANFT.tokenOfOwnerByIndex(buyer.address, 1);  // 1970
    let nft2 = sANFT.tokenOfOwnerByIndex(buyer.address, 2);  // 2000
    await sANFTManager.connect(buyer).merge([nft0, nft1, nft2]);
    expect(await sANFT.balanceOf(buyer.address)).equal(1);
    nft = await sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].saleId).equal(saleId);
    expect(bundle[0].remainingAmount).equal(normalize(49203, 17));

    CL("Checking for merge fee");
    expect(await sANFT.balanceOf(apeWallet.address)).equal(3);
    nft = await sANFT.tokenOfOwnerByIndex(apeWallet.address, 2);
    bundle = await sANFT.getBundle(nft);
    expect(bundle[0].saleId).equal(saleId);
    expect(bundle[0].remainingAmount).equal(normalize(4970, 16));


    let currentBlockTimeStamp;
    CL("Vesting NFT of buyer after first mile stone");
    // list tokens
    await saleData.connect(seller).triggerTokenListing(saleId);

    // before vesting
    nft = sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    bundle = await sANFT.getBundle(nft);
    expect(await sellingToken.balanceOf(buyer.address)).equal(0);
    expect(bundle[0].remainingAmount).equal(normalize(49203, 17));

    CL("first vesting")
    let [ids, amounts] = await sANFT.withdrawables(nft);
    expect(ids[0]).equal(saleId);
    expect(amounts[0]).equal(normalize(98406, 16)); // 20% vested

    CL("Partial withdraw")
    await sANFT.connect(buyer).withdraw(nft, [normalize(48406, 16)]);
    expect(await sellingToken.balanceOf(buyer.address)).equal(normalize(48406, 16));
    nft = sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    [ids, amounts] = await sANFT.withdrawables(nft);
    expect(amounts[0]).equal(normalize(50000, 16));

    CL("Full withdraw")
    nft = sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    await sANFT.connect(buyer).withdraw(nft, [0]);
    expect(await sellingToken.balanceOf(buyer.address)).equal(normalize(98406, 16));
    nft = sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    [ids, amounts] = await sANFT.withdrawables(nft);
    expect(amounts[0]).equal(0);

    CL("Moving forward 50 days")
    await network.provider.send("evm_increaseTime", [3600 * 24 * 50])
    await network.provider.send("evm_mine")

    nft = sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    bundle = await sANFT.getBundle(nft);
    [ids, amounts] = await sANFT.withdrawables(nft);
    expect(amounts[0]).equal(normalize(147609, 16)); // additional 30% vested

    CL("Moving forward 50 more days")
    await network.provider.send("evm_increaseTime", [3600 * 24 * 50])
    await network.provider.send("evm_mine")

    nft = sANFT.tokenOfOwnerByIndex(buyer.address, 0);
    bundle = await sANFT.getBundle(nft);
    [ids, amounts] = await sANFT.withdrawables(nft);
    expect(amounts[0]).equal(normalize(393624, 16)); // all vested

    CL("Withdraw payments")
    expect(await tether.balanceOf(abcSale.address)).equal(normalize(10000,6));
    expect(await tether.balanceOf(seller.address)).equal(0);
    await abcSale.connect(seller).withdrawPayment(normalize(4000, 6));
    expect(await tether.balanceOf(seller.address)).equal(normalize(4000,6));
    await abcSale.connect(seller).withdrawPayment(0)
    expect(await tether.balanceOf(seller.address)).equal(normalize(10000,6));
    expect(await tether.balanceOf(apeWallet.address)).equal(normalize(300,6))

    })
  })
})
