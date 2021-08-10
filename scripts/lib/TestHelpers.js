const {assert} = require("chai");

module.exports = {

  init(ethers) {
    this.ethers = ethers
  },

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

  formatBundle(sAArray) {
    for (let i = 0;i<sAArray.length;i++) {
      sAArray[i] = formatSA(sAArray[i])
    }
  },

  formatSA(sA) {
    return {
      saleId: sA.saleId,
      fullAmount: sA.fullAmount.toString(),
      remainingAmount: sA.remainingAmount.toString()
    }
  },

  async signPackedData(hasher, func, privateKey, ...params) {
    const hash = await hasher[func](...params)
    const signingKey = new this.ethers.utils.SigningKey(privateKey)
    const signedDigest = signingKey.signDigest(hash)
    return this.ethers.utils.joinSignature(signedDigest)
  },

  async getTimestamp() {
    return (await this.ethers.provider.getBlock()).timestamp
  },

  addr0: '0x0000000000000000000000000000000000000000',

  async increaseBlockTimestampBy(offset) {
    await this.ethers.provider.send("evm_increaseTime", [offset])
    await this.ethers.provider.send('evm_mine')
  }

}
