const config = require('./config/index')
const addresses = require('./deployedToRopsten.json')
module.exports = [
  addresses.ApeRegistry,
  config['3'].operators
]
