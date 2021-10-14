// the chainId is the index. 1 is Ethereum Mainnet, 1337 is localhost, etc.

const config = {


  '1': {
    tetherAddress: '0xdac17f958d2ee523a2206206994597c13d831ec7'
  },
  '1337': {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906', // signers[3]
    operators: ['0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc'], // signers[2],
    signersList: [
      '0x71be63f3384f5fb98995898a86b02fb2426c5788', // signers[11]
      '0xfabb0ac9d68b0b445fb7357272ff202c5651694a', // signers[12],
      '0x1cbd3b2770909d4e10f157cabc84c7264073c9ec' // signers[13]
    ],
    validity: 24 * 3600 // 1 day
  },
  '4': {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906',
    operators: ['0x36C3D76f3D2Ec925Ab51a028D1C44007EFc6574a']
  },
  '3': {
    apeWallet: '0x90f79bf6eb2c4f870365e785982e1f101e93b906',
    operators: ['0xB298a3987001d4318847488CBcC534221915bAe1']
  }
}

module.exports = config
