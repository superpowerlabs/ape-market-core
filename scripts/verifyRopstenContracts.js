const path = require('path')
const {execSync} = require('child_process')
const addresses = require('../deployedToRopsten.json')
const config = require('../config/index')

const root = path.resolve(__dirname, '..')

for (let contract in addresses) {
  let args = ''
  let arguments = ''
  if (~'SaleDB,TokenRegistry,SANFT'.split(',').indexOf(contract)) {
    args = addresses.ApeRegistry
  } else if (contract === 'SaleData') {
    args = addresses.ApeRegistry + ' ' + config['3'].apeWallet
  } else if (contract === 'SaleFactory') {
    arguments = '--constructor-args arguments.js'
  } else if (contract === 'SANFTManager') {
    args = addresses.ApeRegistry + ' ' + config['3'].apeWallet + ' ' + 100
  }
  console.log(`npx hardhat verify --show-stack-traces --network ropsten ${arguments} ${addresses[contract]} ${args} `)
}