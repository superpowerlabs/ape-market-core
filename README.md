# APE Market Core

## Install the dependencies and test the contracts

```
npm i
npm run compile
npm run test
```

To see how much gas is consumed during tests run
```
npm run test:gas
```

To check the size of the contract, after compiling
```
npm run size
```

To deploy to a local node, run
```
npx hardhat node
```
open a new terminal and run
```
bin/deploy.sh localhost --save
```

To export the ABIs of the contracts, run
```
npm run export
```
