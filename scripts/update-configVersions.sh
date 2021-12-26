#!/bin/bash

set -xe

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

categories=[\"DeFi\",\"Games\",\"NFTs\",\"Social\",\"Exchanges\",\"Media\",\"Books\",\"Food\",\"Insurance\",\"Health\",\"Other\"]

# TVC
subscriptionTvc=$(cat ../abi/Subscription.tvc | base64 $prefix)
subscriptionIndexTvc=$(cat ../abi/SubscriptionIndex.tvc | base64 $prefix)
subscriptionServiceTvc=$(cat ../abi/SubscriptionService.tvc | base64 $prefix)
subscriptionServiceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64 $prefix)

#ABI
abiSubsManDebot=$(cat ../abi/SubsMan.abi.json | jq -c .| base64 $prefix)

abiServiceContract=$(cat ../abi/SubscriptionService.abi.json | jq -c .| base64 $prefix)
abiServiceIndexContract=$(cat ../abi/SubscriptionServiceIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionContract=$(cat ../abi/Subscription.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIndexContract=$(cat ../abi/SubscriptionIndex.abi.json | jq -c .| base64 $prefix)


LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

configAddr=$(cat ./configVersions.addr)
echo $configAddr

tonos-cli --url $NETWORK call $configAddr setCategories "{\"categoriesInput\": $categories}" --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvc "{\"tvcSubscriptionServiceInput\":\"$subscriptionServiceTvc\", \"tvcSubscriptionInput\":\"$subscriptionTvc\",\"tvcSubscriptionServiceIndexInput\":\"$subscriptionServiceIndexTvc\",\"tvcSubscriptionIndexInput\":\"$subscriptionIndexTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setAbi "{\"abiServiceContractInput\":\"$abiServiceContract\",\"abiServiceIndexContractInput\":\"$abiServiceIndexContract\",\"abiSubscriptionContractInput\":\"$abiSubscriptionContract\", \"abiSubscriptionIndexContractInput\":\"$abiSubscriptionIndexContract\",\"abiSubsManDebotInput\":\"$abiSubsManDebot\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
