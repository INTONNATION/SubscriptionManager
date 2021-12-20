#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

tondev sol compile ../contracts/mTIP-3/RootTokenContract.sol -o ../abi;
tondev sol compile ../contracts/mTIP-3/TONTokenWallet.sol -o ../abi;
name=`echo mUSDT | xxd -ps -c 20000`
wallet_code=`tvm_linker decode --tvc ../abi/TONTokenWallet.tvc | grep 'code:' | awk '{print $NF}'`
tvc=`tvm_linker init ../abi/RootTokenContract.tvc "{\"_randomNonce\": 1, \"name\": \"$name\",\"symbol\": \"$name\", \"decimals\": 6, \"wallet_code\": \"$wallet_code\"}" ../abi/RootTokenContract.abi.json | grep 'Saved contract to file' | awk '{print $NF}'`
mv $tvc ../abi/RootTokenContract.tvc
tos=tonos-cli

CONTRACT_NAME=RootTokenContract

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
genkeypair "$1" "$seed"
pub=`cat $1.keys.json | jq .public -r`
echo GENADDR $1 ----------------------------------------------
genaddr $1
CONTRACT_ADDRESS=$(get_address)
echo GIVER $1 ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
$tos --url $NETWORK deploy ../abi/$1.tvc "{\"root_public_key_\": \"0x$pub\", \"root_owner_address_\": \"0:0000000000000000000000000000000000000000000000000000000000000000\"}" --sign $1.keys.json --abi ../abi/$1.abi.json
echo -n $CONTRACT_ADDRESS > $1.addr
}

deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)