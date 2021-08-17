const path = require('path')
const fs = require('fs-extra')

let envJson = path.resolve(__dirname, 'env.json')
if (!fs.existsSync(envJson)) {
  fs.writeFileSync(envJson, '{"rinkeby": {"url": ""}}')
}

module.exports = {
  envJson: require('./env.json')
}
