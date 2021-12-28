#!/bin/bash
set -xe

trap terminate SIGINT
terminate(){
    pkill -SIGINT -P $$
    exit
}

# Deploy Subscription Manager
./deploy-SubsMan.sh 

# Need to run once to deploy TIP-3 tokens (emulation of main net)
#./deploy-TIP-3.sh USDT
#./deploy-TIP-3.sh EUPI

# Convert system (mTIP-3 and TIP-3 convert system wallets and mTIP-3 root) with configs
./deploy-Convert.sh USDT &
./deploy-Convert.sh EUPI &

# configs
./deploy-configVersions.sh &

# Update Subscription Manager
./update-SubsMan.sh
wait