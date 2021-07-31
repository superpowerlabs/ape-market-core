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
  }

}
