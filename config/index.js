// the chainId is the index. 1 is Ethereum Mainnet, 1337 is localhost, etc.

const baseConfig = {
  feePermillage: 10
}

const config = {
  '1': Object.assign(baseConfig, {
    tetherAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7'
  }),
  '1337': Object.assign(baseConfig, {
    apeWallet: '0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f', // signers[8]
    operators: ['0xa0Ee7A142d267C1f36714E4a8F75612F20a79720'], // signers[9]
    validators: ['0x70997970C51812dc3A010C7d01b50e0d17dc79C8'], // signers[1]
    feePermillage: 10
  })
}

module.exports = config
