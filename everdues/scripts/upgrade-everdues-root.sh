#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=net.ton.dev
MAINNET=https://mainnet.evercloud.dev/a0b43df808ec4afe8d75ef8bdc3054d3
FLD=https://gql.custler.net
NETWORK=$MAINNET

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

./compile.sh

CONTRACT_NAME=EverduesRoot

function deploy {
CONTRACT_ADDRESS=`cat ./envs/$2-EverduesRoot.addr`
owner=`cat dev-single.msig.addr| grep "Raw address" | awk '{print $3}'`
code=`tvm_linker decode --tvc ../abi/EverduesRoot.tvc | grep code: | awk '{ print $2 }'`
message=`tonos-cli -j body upgrade "{\"code\":\"$code\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 5T --bounce true --allBalance false --payload "$message"
}

deploy $CONTRACT_NAME $1

echo $CONTRACT_ADDRESS
