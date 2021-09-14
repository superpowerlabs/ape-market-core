#!/usr/bin/env node
const fs = require('fs-extra')
const path = require('path')

const ABIs = {
  when: (new Date).toISOString(),
  contracts: {}
}

let contracts = [
  'registry/ApeRegistry',
  'nft/SANFT',
  'nft/SANFTManager',
  'sale/SaleData',
  'sale/SaleDB',
  'sale/Sale',
  'sale/SaleFactory',
  'sale/SaleSetupHasher',
  'sale/TokenRegistry',
  'user/Profile'
]

for (let contract of contracts) {
  let name = contract.replace(/^.+\//, '')
  let source = path.resolve(__dirname, `../artifacts/contracts/${contract}.sol/${name}.json`)
  let json = require(source)
  ABIs.contracts[name] = json.abi
}

// we need an ERC20 token for the app
let json = require(path.resolve(__dirname, `../artifacts/@openzeppelin/contracts/token/ERC20/ERC20.sol/ERC20.json`))
ABIs.contracts['ERC20'] = json.abi

fs.writeFileSync(path.resolve(__dirname, '../config/ABIs.json'), JSON.stringify(ABIs, null, 2))
