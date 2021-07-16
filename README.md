# Testing App for Ape Contracts

## To run the code locally:

### clone the repository

`git clone -b main https://github.com/royliu/ape ape`

replace the final `ape` with the name of target directory you would like to clone to, or leave it out to use ape

### install necessary packages

`npm install`

### start hardhat local node - it will list 20 accounts.
`npx hardhat node`

### import the above accounts into meta mask. I am including my local accounts as example

The following accounts are used to
WARNING: Do NOT store anything valuable in these accounts. They are shared across
networks. e.g local, testnet and mainnet.

ApeOwner: Deployer of SANFT and Sale contracts.  Receiver of all the fees.
Account #0: 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 (10000 ETH)
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

TetherOwner: Deployer of tether contract
Account #1: 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 (10000 ETH)
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

AbcOwner: Deployer of Abc Token and Abc Sale
Account #2: 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc (10000 ETH)
Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

AbcOwner: Deployer of Xyz Token and Xyz Sale
Account #3: 0x90f79bf6eb2c4f870365e785982e1f101e93b906 (10000 ETH)
Private Key: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6

Investor1
Account #4: 0x15d34aaf54267db7d7c367839aaf71a00a2c6a65 (10000 ETH)
Private Key: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a

Investor2
Account #5: 0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc (10000 ETH)
Private Key: 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba

### deploy the smart contracts

`bin/deploy.sh localhost`

### build app

`npm run build`

### start app

`npm start`

### run app against Rinkeby

To test the app on Rinkeby testnet, to avoid publishing private keys on GitHub,
you must set up a git-ignored configuration file, called `env.json`, in
the root of the project. The JSON file must contains the settings necessary in `hardhat-config.js` for that
network. For example, if we need only settings for Rinkeby (like it is at the moment), the file can
be something like this:
```
{
  "rinkeby": {
    "url": "{api_url?api_token}",
    "accounts": [
      "{private_key1}",
      "{private_key2}",
      ...
    ],
    "chainId": 4
  }
}
```
There is an example file in the root, called `env-example.json`.
If the file does not exist, during deployment and tests, an empty json file will be created to avoid breaking hardhat tasks.
