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

CONTRACT_NAME=EverduesRoot

function deploy {
CONTRACT_ADDRESS=`cat ./envs/$2-EverduesRoot.addr`
if [[ $2 != "prod" ]]; then
    owner=`cat dev-single.msig.addr`
else
    owner=`cat prod-multisig.msig.addr`
fi
pubkey=$3
message=`tonos-cli -j body deployServiceAccount "{\"pubkey\":\"$pubkey\",\"tokens\":\"5000000\",\"additional_gas\":\"0\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json2 --dest $CONTRACT_ADDRESS --value 3T --bounce true --allBalance false --payload "$message"
#account=``
#tonos-cli callx -m submitTransaction --addr $account --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 3T --bounce true --allBalance false --payload "$message"
}
deploy $CONTRACT_NAME $1 $2
