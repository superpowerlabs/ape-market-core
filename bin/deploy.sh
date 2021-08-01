#!/usr/bin/env bash
# must be run from the root

if [[ "$2" == "--save" ]]; then
  SAVE_DEPLOYED_ADDRESSES=1 npx hardhat run scripts/deploy.js --network $1
else
  npx hardhat run scripts/deploy.js --network $1
fi