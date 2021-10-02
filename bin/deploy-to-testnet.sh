#!/usr/bin/env bash
# must be run from the root

echo "Deploying contracts to $1"

VERBOSE_LOG=1 npx hardhat run scripts/deployToTestnet.js --network $1
