#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net1.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

tondev sol compile ../contracts/MetaduesRoot.sol -o ../abi;
tondev sol compile ../contracts/MetaduesAccount.sol -o ../abi;
tondev sol compile ../contracts/Platform.sol -o ../abi;
tondev sol compile ../contracts/Subscription.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionService.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionServiceIndex.sol -o ../abi;
tondev sol compile ../contracts/MetaduesFeeProxy.sol -o ../abi;

CONTRACT_NAME=MetaduesRoot

#Giver FLD
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
function giver {
       tonos-cli --url $NETWORK call --abi ../abi/local_giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":20000000000}"
}

# Giver DEVNET
# giver=0:705e21688486a905a2f83f940dfbafcd4d319cff31d4189ebf4483e16553fa33
# function giver {
# tonos-cli --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":10000000000, \"bounce\":\"false\"}"
# }

function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function genseed {
tonos-cli genphrase > $1.seed
}

function genpubkey {
tonos-cli genpubkey "$1" > $2.pub
}

function genkeypair {
tonos-cli getkeypair $1.keys.json "$2"
}

function genaddr {
tonos-cli genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey $1.keys.json > log.log
}

function deploy {
genseed $1
seed=`cat $1.seed | grep -o '".*"' | tr -d '"'`
echo "DeBot seed - $seed"
genpubkey "$seed" "client"
pub=`cat $1.pub | grep "Public key" | awk '{print $3}'`
echo "Debot pubkey - $pub"
genkeypair "$1" "$seed"
echo GENADDR $1 ----------------------------------------------
genaddr $1
CONTRACT_ADDRESS=$(get_address)
echo -n $CONTRACT_ADDRESS > $1.addr
echo GIVER $1 ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
tonos-cli --url $NETWORK deploy ../abi/$1.tvc "{}" --sign $1.keys.json --abi ../abi/$1.abi.json

# Categories
categories=[\"DeFi\",\"Games\",\"NFTs\",\"Social\",\"Exchanges\",\"Media\",\"Books\",\"Food\",\"Insurance\",\"Health\",\"Other\"]

# TVC
platformTvc=$(cat ../abi/Platform.tvc | base64 $prefix)
metaduesAccountTvc=$(cat ../abi/MetaduesAccount.tvc | base64 $prefix)
subscriptionTvc=$(cat ../abi/Subscription.tvc | base64 $prefix)
subscriptionIndexTvc=$(cat ../abi/SubscriptionIndex.tvc | base64 $prefix)
subscriptionServiceTvc=$(cat ../abi/SubscriptionService.tvc | base64 $prefix)
subscriptionServiceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64 $prefix)
subscriptionidentificatorIndexTvc=$(cat ../abi/SubscriptionIdentificatorIndex.tvc | base64 $prefix)
feeProxyTvc=$(cat ../abi/MetaduesFeeProxy.tvc | base64 $prefix)

#ABI
abiPlatformContract=$(cat ../abi/Platform.abi.json | jq -c .| base64 $prefix)
abiMetaduesAccountContract=$(cat ../abi/MetaduesAccount.abi.json | jq -c .| base64 $prefix)
abiMetaduesRootContract=$(cat ../abi/MetaduesRoot.abi.json | jq -c .| base64 $prefix)
abiTIP3RootContract=$(cat ../ton-eth-bridge-token-contracts/build/TokenRoot.abi.json | jq -c .| base64 $prefix)
abiTIP3TokenWalletContract=$(cat ../ton-eth-bridge-token-contracts/build/TokenWallet.abi.json | jq -c .| base64 $prefix)
abiServiceContract=$(cat ../abi/SubscriptionService.abi.json | jq -c .| base64 $prefix)
abiServiceIndexContract=$(cat ../abi/SubscriptionServiceIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionContract=$(cat ../abi/Subscription.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIndexContract=$(cat ../abi/SubscriptionIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIdentificatorIndexContract=$(cat ../abi/SubscriptionIdentificatorIndex.abi.json | jq -c .| base64 $prefix)
abiFeeProxyContract=$(cat ../abi/MetaduesFeeProxy.abi.json | jq -c .| base64 $prefix)

# Set categories
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setCategories "{\"categoriesInput\": $categories}" --abi ../abi/$1.abi.json 

# Set TVCs
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcPlatform "{\"tvcPlatformInput\":\"$platformTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcMetaduesAccount "{\"tvcMetaduesAccountInput\":\"$metaduesAccountTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcSubscription "{\"tvcSubscriptionInput\":\"$subscriptionTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcSubscriptionIndex "{\"tvcSubscriptionIndexInput\":\"$subscriptionIndexTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcSubscriptionService "{\"tvcSubscriptionServiceInput\":\"$subscriptionServiceTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcSubscriptionServiceIndex "{\"tvcSubscriptionServiceIndexInput\":\"$subscriptionServiceIndexTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcSubscriptionIdentificatorIndex "{\"tvcSubscriptionIdentificatorIndexInput\":\"$subscriptionidentificatorIndexTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvcFeeProxy "{\"tvcFeeProxyInput\":\"$feeProxyTvc\"}"  --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setTvc "{}"  --abi ../abi/$1.abi.json 

# SET ABIs
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiPlatformContract "{\"abiPlatformContractInput\":\"$abiPlatformContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiMetaduesAccountContract "{\"abiMetaduesAccountContractInput\":\"$abiMetaduesAccountContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiMetaduesRootContract "{\"abiMetaduesRootContractInput\":\"$abiMetaduesRootContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiTIP3RootContract "{\"abiTIP3RootContractInput\":\"$abiTIP3RootContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiTIP3TokenWalletContract "{\"abiTIP3TokenWalletContractInput\":\"$abiTIP3TokenWalletContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiServiceContract "{\"abiServiceContractInput\":\"$abiServiceContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiServiceIndexContract "{\"abiServiceIndexContractInput\":\"$abiServiceIndexContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiSubscriptionContract "{\"abiSubscriptionContractInput\":\"$abiSubscriptionContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiSubscriptionIndexContract "{\"abiSubscriptionIndexContractInput\":\"$abiSubscriptionIndexContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiSubscriptionIdentificatorIndexContract "{\"abiSubscriptionIdentificatorIndexContractInput\":\"$abiSubscriptionIdentificatorIndexContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbiFeeProxyContract "{\"abiFeeProxyContractInput\":\"$abiFeeProxyContract\"}" --abi ../abi/$1.abi.json 
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setAbi "{}"  --abi ../abi/$1.abi.json 

tonos-cli --url $NETWORK call $CONTRACT_ADDRESS deployFeeProxy "{\"currencies\":[\"0:5b65a97c28a40ecd8713113e08a8e8317ee4455b53fce495a363e41adf6282dc\",\"0:2306fe44aca48701039ab7cbad96bf60dc2c51f2250f052d24c3a110e3fada8b\"]}" --abi ../abi/$1.abi.json
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS setFees "{\"service_fee_\":\"5\",\"subscription_fee_\":\"5\"}" --abi ../abi/$1.abi.json
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS installOrUpgradeMTDSRevenueDelegationAddress "{\"revenue_to\":\"0:81ef55e449aab0ec7c419081b924e012fd7e8628c8274de7baa5e6b2b15e0a8f\"}" --abi ../abi/$1.abi.json
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS installOrUpgradeMTDSRootAddress "{\"mtds_root_\":\"0:2306fe44aca48701039ab7cbad96bf60dc2c51f2250f052d24c3a110e3fada8b\"}" --abi ../abi/$1.abi.json
tonos-cli --url $NETWORK call $CONTRACT_ADDRESS installOrUpgradeDexRootAddress "{\"dex_root\":\"0:a2004013ca1247051dd887d6c9976f76a7b11f9bb537bf4bf392dd1990f6815f\"}" --abi ../abi/$1.abi.json
}

deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
