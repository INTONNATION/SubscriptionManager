#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

for i in ../contracts/SubsMan ../contracts/Subscription ../contracts/SubscriptionServiceIndex ../contracts/SubscriptionService ../contracts/SubscriptionIndex ../contracts/Wallet; do
       tondev sol compile $i.sol -o ../abi;
done

tos=tonos-cli

CONTRACT_NAME=SubsMan

# Giver FLD
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
function giver {
       $tos --url $NETWORK call --abi ../abi/local_giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":20000000000}"
}

# Giver DEVNET
#giver=0:ece57bcc6c530283becbbd8a3b24d3c5987cdddc3c8b7b33be6e4a6312490415
#function giver {
#$tos --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":5000000000, \"bounce\":\"false\"}"
#}

function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function genseed {
$tos genphrase > $1.seed
}

function genpubkey {
$tos genpubkey "$1" > $2.pub
}

function genkeypair {
$tos getkeypair $1.keys.json "$2"
}

function genaddr {
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey $1.keys.json > log.log
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
echo GIVER $1 ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
$tos --url $NETWORK deploy ../abi/$1.tvc "{}" --sign $1.keys.json --abi ../abi/$1.abi.json
echo -n $CONTRACT_ADDRESS > $1.addr
}

deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

IMAGE=$(base64 -w 0 ../abi/Subscription.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionBase "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 -w 0 ../abi/Wallet.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionWalletCode "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 -w 0 ../abi/SubscriptionIndex.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionIndexCode "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 -w 0 ../abi/SubscriptionService.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionService "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
IMAGE=$(base64 -w 0 ../abi/SubscriptionServiceIndex.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionServiceIndex "{\"image\":\"$IMAGE\"}" --sign $CONTRACT_NAME.keys.json --abi ../abi/$CONTRACT_NAME.abi.json
echo debot $CONTRACT_ADDRESS