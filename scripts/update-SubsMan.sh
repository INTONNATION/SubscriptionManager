#!/bin/bash

set -xe

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

CONTRACT_NAME="SubsMan"
CONTRACT_ADDRESS=`cat $CONTRACT_NAME.addr`
tos=tonos-cli

IMAGE=$(base64 $prefix ../abi/Subscription.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionBase "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 $prefix ../abi/mUSDTTokenWallet.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionWalletCode_mUSDT "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 $prefix ../abi/mEUPITokenWallet.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionWalletCode_mEUPI "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 $prefix ../abi/SubscriptionIndex.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionIndexCode "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 $prefix ../abi/SubscriptionService.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionService "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 $prefix ../abi/SubscriptionServiceIndex.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionServiceIndex "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json