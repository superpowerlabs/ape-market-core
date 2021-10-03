// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require('hardhat');
const DeployUtils = require('./lib/DeployUtils')

const conf = require('../env.token.js') /*

^^^ you MUST create the file above before running the script

Examples:

// standard
{
  "signerIndex": 3,
  "tokenName": "ABC Token",
  "tokenAbbr": "ABC"
}

// tether mock
{
  "signerIndex": 3,
  "isTether": true
}

signerIndex is the index of the wallet in ethers.signers array
 */

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.


  const deployUtils = new DeployUtils(hre.ethers)
  const chainId = await deployUtils.currentChainId()
  const data = await deployUtils.initAndDeployToken(conf)

  for (let i in data) {
    data[i] = data[i].address ? data[i].address : data[i]
  }
  console.log(data)


}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
