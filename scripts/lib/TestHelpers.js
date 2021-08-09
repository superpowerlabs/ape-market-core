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

  formatBigNumbers(ethers, obj) {
    for (let key in obj) {
      if (obj[key] instanceof ethers.BigNumber) {
        try {
          obj[key] = obj[key].toNumber()
        } catch(e) {
          obj[key] = obj[key].toString()
        }
      }
    }
    return obj
  },

  async signPackedData(ethers, hasher, func, privateKey, ...params) {
    const hash = await hasher[func](...params)
    const signingKey = new ethers.utils.SigningKey(privateKey)
    const signedDigest = signingKey.signDigest(hash)
    return ethers.utils.joinSignature(signedDigest)
  },

  async getTimestamp(ethers) {
    return (await ethers.provider.getBlock()).timestamp
  },

  addr0: '0x0000000000000000000000000000000000000000'

}
