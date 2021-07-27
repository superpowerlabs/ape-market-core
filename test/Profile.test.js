const {expect, assert} = require("chai")
const {assertThrowsMessage, formatBundle} = require('./helpers')

describe("Debug", function () {

  let Profile
  let profile
  let now

  let day = 60 * 60 * 24

  let owner, account1, account2, account3

  let addr0 = '0x0000000000000000000000000000000000000000'


  async function getSignatureByAccount1(addr1, addr2, ts) {
    const hash = await profile.encodeForSignature(addr1, addr2, ts)
    const signingKey = new ethers.utils.SigningKey('0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d')
    const signedDigest = signingKey.signDigest(hash)
    return ethers.utils.joinSignature(signedDigest)
  }

  before(async function () {
    [owner, account1, account2, account3] = await ethers.getSigners()
  })

  async function initNetworkAndDeploy() {

    Profile = await ethers.getContractFactory("Profile")
    profile = await Profile.deploy()
    await profile.deployed()

    now = Math.round(Date.now() / 1000)

  }

  describe('#associateAccount', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should successfully associate account1 to account2", async function () {

      // account1 is the signer
      let signature = await getSignatureByAccount1(account1.address, account2.address, now)

      await expect(profile.connect(account2).associateAccount(account1.address, now, signature))
          .emit(profile, 'AccountsAssociated')
          .withArgs(account2.address, account1.address);


    })

    it("should throw if not signed by the account to be associated", async function () {

      let signature = await getSignatureByAccount1(account3.address, account2.address, now)

      await expect(profile.connect(account2).associateAccount(account3.address, now, signature))
          .revertedWith('Profile: invalid signature')

    })

    it("should throw if the transaction is executed after validity late", async function () {

      let signature = await getSignatureByAccount1(account1.address, account2.address, now - (2 * day) )

      await expect(profile.connect(account2).associateAccount(account1.address, now - (2 * day), signature))
          .revertedWith('Profile: request is expired')

    })

    it("should throw if invalid address", async function () {

      let signature = await getSignatureByAccount1(addr0, account2.address, now - (2 * day) )

      await expect(profile.connect(account2).associateAccount(addr0, now - (2 * day), signature))
          .revertedWith('Profile: no invalid accounts')

    })

  })

  describe('#dissociateAccount', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should allow associate account2 to dissociate account1", async function () {

      // account1 is the signer
      let signature = await getSignatureByAccount1(account1.address, account2.address, now)
      await profile.connect(account2).associateAccount(account1.address, now, signature)

      await expect(profile.connect(account2).dissociateAccount(account1.address))
          .emit(profile, 'AccountsDissociated')
          .withArgs(account2.address, account1.address);


    })

    it("should allow associate account1 to dissociate account2", async function () {

      // account1 is the signer
      let signature = await getSignatureByAccount1(account1.address, account2.address, now)
      await profile.connect(account2).associateAccount(account1.address, now, signature)

      await expect(profile.connect(account1).dissociateAccount(account2.address))
          .emit(profile, 'AccountsDissociated')
          .withArgs(account1.address, account2.address);


    })

    it("should throw if trying to dissociate not-associated account", async function () {

      let signature = await getSignatureByAccount1(account1.address, account2.address, now)
      await profile.connect(account2).associateAccount(account1.address, now, signature)

      await expect(profile.connect(account2).dissociateAccount(account3.address))
          .revertedWith('Profile: association not found')

    })

  })

  describe('#areAddressesAssociated', async function () {

    beforeEach(async function () {
      await initNetworkAndDeploy()
    })

    it("should verify that account2 is associate to account1", async function () {

      // account1 is the signer
      let signature = await getSignatureByAccount1(account1.address, account2.address, now)
      await profile.connect(account2).associateAccount(account1.address, now, signature)
      assert.isTrue(await profile.areAccountsAssociated(account1.address, account2.address))

    })

    it("should verify that account2 is not associate to account1", async function () {

      // account1 is the signer
      let signature = await getSignatureByAccount1(account1.address, account2.address, now)
      await profile.connect(account2).associateAccount(account1.address, now, signature)
      assert.isFalse(await profile.areAccountsAssociated(account1.address, account3.address))

    })

    it("should verify that neither account2 nor account1 are associated to any other account", async function () {

      // account1 is the signer
      assert.isFalse(await profile.areAccountsAssociated(account1.address, account2.address))

    })


  })



})