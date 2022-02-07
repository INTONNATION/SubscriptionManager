#!/bin/bash

set -xe

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

categories=[\"DeFi\",\"Games\",\"NFTs\",\"Social\",\"Exchanges\",\"Media\",\"Books\",\"Food\",\"Insurance\",\"Health\",\"Other\"]

# TVC
metaduesAccountTvc=$(cat ../abi/MetaduesAccount.tvc | base64 $prefix)
subscriptionTvc=$(cat ../abi/Subscription.tvc | base64 $prefix)
subscriptionIndexTvc=$(cat ../abi/SubscriptionIndex.tvc | base64 $prefix)
subscriptionServiceTvc=$(cat ../abi/SubscriptionService.tvc | base64 $prefix)
subscriptionServiceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64 $prefix)
subscriptionidentificatorIndexTvc=$(cat ../abi/SubscriptionidentificatorIndex.tvc | base64 $prefix)

#ABI
abiMetaduesRootContract=$(cat ../abi/MetaduesRoot.abi.json | jq -c .| base64 $prefix)
abiTIP3RootContract=$(cat ../ton-eth-bridge-token-contracts/build/TokenRoot.abi.json | jq -c .| base64 $prefix)
abiServiceContract=$(cat ../abi/SubscriptionService.abi.json | jq -c .| base64 $prefix)
#abiServiceIndexContract=$(cat ../abi/SubscriptionServiceIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionContract=$(cat ../abi/Subscription.abi.json | jq -c .| base64 $prefix)
#abiSubscriptionIndexContract=$(cat ../abi/SubscriptionIndex.abi.json | jq -c .| base64 $prefix)
#abiSubscriptionidentificatorIndexContract=$(cat ../abi/SubscriptionidentificatorIndex.abi.json | jq -c .| base64 $prefix)


LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

configAddr=$(cat ./configVersions.addr)
echo $configAddr

# Set categories
tonos-cli --url $NETWORK call $configAddr setCategories "{\"categoriesInput\": $categories}" --abi ../abi/configVersions.abi.json --sign configVersions.keys.json

# Set TVCs
tonos-cli --url $NETWORK call $configAddr setTvcMetaduesAccount "{\"tvcMetaduesAccountInput\":\"$metaduesAccountTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvcSubscription "{\"tvcSubscriptionInput\":\"$subscriptionTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvcSubscriptionIndex "{\"tvcSubscriptionIndexInput\":\"$subscriptionIndexTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvcSubscriptionService "{\"tvcSubscriptionServiceInput\":\"$subscriptionServiceTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvcSubscriptionServiceIndex "{\"tvcSubscriptionServiceIndexInput\":\"$subscriptionServiceIndexTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvcSubscriptionidentificatorIndex "{\"tvcSubscriptionidentificatorIndexInput\":\"$subscriptionidentificatorIndexTvc\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setTvc "{}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json


# SET ABIs
tonos-cli --url $NETWORK call $configAddr setAbiMetaduesRootContract "{\"abiMetaduesRootContractInput\":\"$abiMetaduesRootContract\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiTIP3RootContract "{\"abiTIP3RootContractInput\":\"$abiTIP3RootContract\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiServiceContract "{\"abiServiceContractInput\":\"$abiServiceContract\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
#tonos-cli --url $NETWORK call $configAddr setAbiServiceIndexContract "{\"abiSubsManDebotInput\":\"$abiSubsManDebot\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiSubscriptionContract "{\"abiSubscriptionContractInput\":\"$abiSubscriptionContract\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
#tonos-cli --url $NETWORK call $configAddr setAbiSubscriptionIndexContract "{\"abiSubsManDebotInput\":\"$abiSubsManDebot\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
#tonos-cli --url $NETWORK call $configAddr setAbiSubscriptionidentificatorIndexContract "{\"abiSubsManDebotInput\":\"$abiSubsManDebot\"}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json
tonos-cli --url $NETWORK call $configAddr setAbi "{}"  --abi ../abi/configVersions.abi.json --sign configVersions.keys.json