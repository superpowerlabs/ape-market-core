const {assert} = require("chai");

module.exports = {

  async assertThrowsMessage(promise, message) {
    try {
      await promise
      throw new Error('It did not throw')
    } catch (e) {
      const shouldBeTrue = e.message.indexOf(message) > -1
      if (!shouldBeTrue) {
        console.error('Expected: ', message)
        console.error(e.message)
        console.log(e)
      }
      assert.isTrue(shouldBeTrue)
    }
  },

  formatBundle(bundle) {
    const result = {}
    result.creationTime = bundle.creationTime.toNumber()
    result.acquisitionTime = bundle.acquisitionTime.toNumber()
    result.sas = []
    for (let sa of bundle.sas) {
      result.sas.push({
        sale: sa.sale,
        remainingAmount: sa.remainingAmount.toNumber(),
        vestedPercentage: sa.vestedPercentage.toNumber()
      })
    }
    return result
  },

  async signNewSale(
      ethers, factory, saleId, setup, schedule,
      // The private key here is the signers[1] account on hardhat default testing chain
      privateKey = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'
  ) {
    const hash = await factory.encodeForSignature(saleId, setup, schedule)
    const signingKey = new ethers.utils.SigningKey(privateKey)
    const signedDigest = signingKey.signDigest(hash)
    return ethers.utils.joinSignature(signedDigest)
  },

  async getTimestamp(ethers) {
    return (await ethers.provider.getBlock()).timestamp
  },

  addr0: '0x0000000000000000000000000000000000000000'

}
