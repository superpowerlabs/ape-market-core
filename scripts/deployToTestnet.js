// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const DeployUtils = require('./lib/DeployUtils')

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.

  const ethers = hre.ethers
  const [
    owner,
    apeWallet,
    operator,
    usdtOwner
  ] = await ethers.getSigners()

  const deployUtils = new DeployUtils(ethers)
  const chainId = await deployUtils.currentChainId()
  let data = await deployUtils.initAndDeploy({
    operators: [operator.address],
    apeWallet: apeWallet.address,
    usdtOwner
  })

  const aBC = await deployUtils.deployERC20(usdtOwner, 'Abc Token', 'ABC')
  const mNO = await deployUtils.deployERC20(usdtOwner, 'Mno Token', 'MNO')
  const xYZ = await deployUtils.deployERC20(usdtOwner, 'Xyz Token', 'XYZ')

  await data.uSDT.connect(usdtOwner).transfer(apeWallet.address, 1e11)

  data = Object.assign(data, {
    aBC,
    mNO,
    xYZ
  })

  for (let i in data) {
    data[i] = data[i].address ? data[i].address : data[i]
  }
  console.log(data)

  const extraData = {
    paymentTokens: {},
    sellingTokens: {}
  }
  for (let k of 'uSDT'.split(',')) {
    extraData.paymentTokens[k.toUpperCase()] = data[k]
  }
  for (let k of 'aBC,mNO,xYZ'.split(',')) {
    extraData.sellingTokens[k.toUpperCase()] = data[k]
  }

  await deployUtils.saveConfig(chainId, data, extraData)
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
