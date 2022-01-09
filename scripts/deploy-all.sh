#!/bin/bash
set -xe

# Need to run once to deploy TIP-3 tokens (emulation of main net)
#./deploy-TIP-3.sh USDT
#./deploy-TIP-3.sh EUPI

# configs
./deploy-configVersions.sh

# Deploy Subscription Manager
./deploy-SubsMan.sh 

# Convert system (mTIP-3 and TIP-3 convert system wallets and mTIP-3 root) with configs
./deploy-Convert.sh USDT # Don't deploy if no changes
#./deploy-Convert.sh EUPI