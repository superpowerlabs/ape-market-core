#!/usr/bin/env bash
# must be run from the root

echo "Deploying single contract to $1"

VERBOSE_LOG=1 DEPLOY_SINGLE_CONTRACT=1 npx hardhat run scripts/deployToTestnet.js --network $1
