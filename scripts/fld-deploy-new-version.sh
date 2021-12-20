#!/bin/bash

set -xe

subscriptionTvc=$(cat ../abi/Subscription.tvc | base64)
subscriptionIndexTvc=$(cat ../abi/SubscriptionIndex.tvc | base64)
serviceTvc=$(cat ../abi/SubscriptionService.tvc | base64)
serviceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64)
walletTvc=$(cat ../abi/Wallet.tvc | base64)

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

#Current config addr 0:f4eea3cfdc1d5903ed330fb8366532e610a7ebfa3b6cbf7fdf97be87e112ef20
configAddr=$(cat ./configVersions.addr)
echo $configAddr



tonos-cli --url $NETWORK call $configAddr setTvc "{\"tvcServiceInput\":\"$serviceTvc\", \"tvcWalletInput\":\"$walletTvc\",\"tvcSubsciptionInput\":\"$subscriptionTvc\",\"tvcSubscriptionServiceIndexInput\":\"$serviceIndexTvc\",\"tvcSuscriptionIndexInput\":\"$subscriptionIndexTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json

