#!/bin/bash

set -xe

if [[ $1 = 'linux' ]]; then
    prefix='-w0'
fi

subscriptionTvc=$(cat ../abi/Subscription.tvc | base64 $prefix)
subscriptionIndexTvc=$(cat ../abi/SubscriptionIndex.tvc | base64 $prefix)
subscriptionServiceTvc=$(cat ../abi/SubscriptionService.tvc | base64 $prefix)
serviceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64 $prefix)
walletTvc=$(cat ../abi/Wallet.tvc | base64 $prefix)
abiServiceContract=$(cat ../abi/SubscriptionService.abi.json | jq -c .| base64 $prefix)
abiServiceIndexContract=$(cat ../abi/SubscriptionServiceIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIndexContract=$(cat ../abi/SubscriptionIndex.abi.json | jq -c .| base64 $prefix)
abiSubsManDebot=$(cat ../abi/SubsMan.abi.json | jq -c .| base64 $prefix)

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

configAddr=$(cat ./configVersions.addr)
echo $configAddr

tonos-cli --url $NETWORK call $configAddr setTvc "{\"tvcSubscriptionServiceInput\":\"$subscriptionServiceTvc\", \"tvcWalletInput\":\"$walletTvc\",\"tvcSubscriptionInput\":\"$subscriptionTvc\",\"tvcSubscriptionServiceIndexInput\":\"$serviceIndexTvc\",\"tvcSubscriptionIndexInput\":\"$subscriptionIndexTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setAbi "{\"abiServiceContractInput\":\"$abiServiceContract\",\"abiServiceIndexContractInput\":\"$abiServiceIndexContract\",\"abiSubscriptionIndexContractInput\":\"$abiSubscriptionIndexContract\",\"abiSubsManDebotInput\":\"$abiSubsManDebot\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json


