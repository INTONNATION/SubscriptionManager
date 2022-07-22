#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$MAINNET

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

./compile.sh

CONTRACT_NAME=EverduesRoot

#Giver FLD
#giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
#function giver {
#       tonos-cli --url $NETWORK call --abi ../abi/local_giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":20000000000}"
#}

# Giver DEVNET
giver=0:705e21688486a905a2f83f940dfbafcd4d319cff31d4189ebf4483e16553fa33

function giver {
tonos-cli --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":6000000000, \"bounce\":\"true\"}"
}

function genseed {
tonos-cli genphrase > $1.seed
}

function genkeypair {
tonos-cli getkeypair $1.keys.json "$2"
}

function genaddr {
tonos-cli genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey $1.keys.json > log.log
}

function deploy {
#genseed $1
#seed=`cat $1.seed | grep -o '".*"' | tr -d '"'`
#genkeypair "$1" "$seed"
CONTRACT_ADDRESS=`cat EverduesRoot.addr`
#giver $CONTRACT_ADDRESS
#echo DEPLOY $1 -----------------------------------------------
owner=`cat single.msig.addr| grep "Raw address" | awk '{print $3}'`

# TVC
feeProxyCode=$(tvm_linker decode --tvc  ../abi/EverduesFeeProxy.tvc | grep code: | awk '{ print $2 }')
#ABI
abiFeeProxyContract=$(cat ../abi/EverduesFeeProxy.abi.json | jq -c .| base64 $prefix)

# Set TVCs
message=`tonos-cli -j body setCodeFeeProxy "{\"codeFeeProxyInput\":\"$feeProxyCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
#
## SET ABIs
message=`tonos-cli -j body setAbiFeeProxyContract "{\"abiFeeProxyContractInput\":\"$abiFeeProxyContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body upgradeFeeProxy "{}"  --abi ../abi/EverduesRoot.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
}

deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
