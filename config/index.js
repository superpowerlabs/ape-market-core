// the chainId is the index. 1 is Ethereum Mainnet, 1337 is localhost, etc.

const config = {
  '1': {
    tetherAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7',
    feePoints: 100,
  },
  '1337':  {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906', // signers[3]
    operators: ['0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc'], // signers[2]
    feePoints: 100
  },
  '4': {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906',
    operators: ['0x36C3D76f3D2Ec925Ab51a028D1C44007EFc6574a'],
    feePoints: 100
  }
}

module.exports = config
