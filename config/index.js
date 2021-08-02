// the chainId is the index. 1 is Ethereum Mainnet, 1337 is localhost, etc.

const config = {
  tether: {
    '1': '0xdac17f958d2ee523a2206206994597c13d831ec7'
  },
  addresses: {
    '1': {
      // TODO: values for localhost, put here as an example. They must be changed:
      apeWallet: '0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f', // signers[8]
      factoryAdmin: '0xa0Ee7A142d267C1f36714E4a8F75612F20a79720', // signers[9]
      validator: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', // signers[1]
      feeAmount: 100
    }
  }
}

module.exports = config
