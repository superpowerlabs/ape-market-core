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
  'sale/Sale',
  'sale/SaleFactory',
  'user/Profile',
  'Ape'
]

for (let contract of contracts) {
  let name = contract.replace(/^.+\//, '')
  let source = path.resolve(__dirname, `../artifacts/contracts/${contract}.sol/${name}.json`)
  let json = require(source)
  ABIs.contracts[name] = json.abi
}

fs.writeFileSync(path.resolve(__dirname, '../config/ABIs.json'), JSON.stringify(ABIs, null, 2))
