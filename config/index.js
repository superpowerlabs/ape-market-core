// the chainId is the index. 1 is Ethereum Mainnet, 1337 is localhost, etc.

const baseConfig = {
  feePoints: 100
}

const config = {
  '1': Object.assign(baseConfig, {
    tetherAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7'
  }),
  '1337': Object.assign(baseConfig, {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906', // signers[3]
    operators: ['0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc'], // signers[2]
    feePoints: 100
  }),
  // This is broken. if bellow is uncommented, 1337's operators will
  // become 0x36C3D76f3D2Ec925Ab51a028D1C44007EFc6574a.
  // Possible reason: Object.assign changes baseConfig as well, so
  // all the changes will be stacked
  /* '4': Object.assign(baseConfig, {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906', // ApeOwner
    operators: ['0x36C3D76f3D2Ec925Ab51a028D1C44007EFc6574a'], // ApeOwner
    validators: ['0x36C3D76f3D2Ec925Ab51a028D1C44007EFc6574a'], // ApeOwner
    feePoints: 300
  }) */
}

module.exports = config
