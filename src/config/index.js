
// for now we need this only to force Git to push the folder
// in the future we will use it appropriately

const config = {
  tether: {
    '1': '0xdac17f958d2ee523a2206206994597c13d831ec7'
  },
  // TODO: must be changed:
  apeWallet: '0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f', // signers[8]
  factoryAdmin: '0xa0Ee7A142d267C1f36714E4a8F75612F20a79720', // signers[9]
  feeAmount: 100
}

module.exports = config
