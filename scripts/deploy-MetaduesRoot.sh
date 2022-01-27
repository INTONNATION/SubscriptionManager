#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
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
tos=tonos-cli

CONTRACT_NAME=MetaduesRoot

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
echo -n $CONTRACT_ADDRESS > $1.addr
echo GIVER $1 ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
$tos --url $NETWORK deploy ../abi/$1.tvc "{}" --sign $1.keys.json --abi ../abi/$1.abi.json

platform_code=$(tvm_linker decode --tvc ../abi/Platform.tvc |grep "code:"|awk '{print $2}')
account_code=$(tvm_linker decode --tvc ../abi/MetaduesAccount.tvc |grep "code:"|awk '{print $2}')
subscription_code=$(tvm_linker decode --tvc ../abi/Subscription.tvc |grep "code:"|awk '{print $2}')
subscription_index_code=$(tvm_linker decode --tvc ../abi/SubscriptionIndex.tvc |grep "code:"|awk '{print $2}')
subscription_identificator_index_code=$(tvm_linker decode --tvc ../abi/SubscriptionIdentificatorIndex.tvc |grep "code:"|awk '{print $2}')
service_code=$(tvm_linker decode --tvc ../abi/SubscriptionService.tvc |grep "code:"|awk '{print $2}')
service_index_code=$(tvm_linker decode --tvc ../abi/SubscriptionServiceIndex.tvc |grep "code:"|awk '{print $2}')


$tos --url $NETWORK call $CONTRACT_ADDRESS installPlatformOnce "{\"code\":\"$platform_code\"}" --abi ../abi/$1.abi.json
$tos --url $NETWORK call $CONTRACT_ADDRESS installOrUpdateAccountCode "{\"code\":\"$account_code\"}" --abi ../abi/$1.abi.json
$tos --url $NETWORK call $CONTRACT_ADDRESS installOrUpdateSubscriptionCode "{\"code\":\"$subscription_code\"}" --abi ../abi/$1.abi.json
$tos --url $NETWORK call $CONTRACT_ADDRESS installOrUpdateSubscriptionIndexCode "{\"code\":\"$subscription_index_code\"}" --abi ../abi/$1.abi.json
$tos --url $NETWORK call $CONTRACT_ADDRESS installOrUpdateSubscriptionIndexIdentificatorCode "{\"code\":\"$subscription_identificator_index_code\"}" --abi ../abi/$1.abi.json
$tos --url $NETWORK call $CONTRACT_ADDRESS installOrUpdateServiceCode "{\"code\":\"$service_code\"}" --abi ../abi/$1.abi.json
$tos --url $NETWORK call $CONTRACT_ADDRESS installOrUpdateServiceIndexCode "{\"code\":\"$service_index_code\"}" --abi ../abi/$1.abi.json
}



deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS