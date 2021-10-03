#!/usr/bin/env bash
# must be run from the root

echo "Deploying token to $1"

VERBOSE_LOG=1 npx hardhat run scripts/deployERC20Token.js --network $1
