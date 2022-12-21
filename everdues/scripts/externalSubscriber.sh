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
owner=`cat dev-single.msig.addr`

pubkey=`tonos-cli -j getkeypair | jq -r .public`
message=`tonos-cli -j body addOrUpdateExternalSubscriber "{\"chain_id\":\"56\",\"pubkey\":\"0x85f43095cb00647277db709bb35ed28cf2dc75481f068706c62294488d52d408\",\"customer\":\"0x91d2741a1371e46298d7f38390696a89d7d79c660e5b444126fd00a19933f252\",\"payee\":\"0x91d2741a1371e46298d7f38390696a89d7d79c660e5b444126fd00a19933f252\",\"everdues_service_address\":\"0:568b3ca0478ed3ba27369ac63de6bdb449f59268228baccc598ad648ef78afb4\",\"subscription_plan\":\"0\",\"tokenAddress\":\"0xeba373b7d85d90cb93cde1b3cb76fd03c532888f9e6e9fdde385f6f2f3c0919b\",\"email\":\"test#gmi.cpm\",\"paid_amount\":\"100000000\",\"status\":true,\"additional_gas\":\"0\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 4T --bounce true --allBalance false --payload "$message"
}
deploy $CONTRACT_NAME $1
