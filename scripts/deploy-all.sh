#!/bin/bash
set -xe

# Need to run once to deploy TIP-3 tokens (emulation of main net)
#./deploy-TIP-3.sh USDT
#./deploy-TIP-3.sh EUPI

# Convert system (mTIP-3 and TIP-3 convert system wallets and mTIP-3 root)
./deploy-Convert.sh USDT
./deploy-Convert.sh EUPI

# configs
./deploy-configVersions.sh
./deploy-configConvert.sh USDT
./deploy-configConvert.sh EUPI

# Fill in or update config
./update-configVersions.sh
./update-configConvert.sh USDT
./update-configConvert.sh EUPI

# Deploy Subscription Manager
./deploy-SubsMan.sh
./update-SubsMan.sh