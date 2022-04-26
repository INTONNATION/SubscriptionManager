#!/bin/bash
set -o pipefail
set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net1.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$DEVNET

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi



CONTRACT_NAME=EverduesRoot
tos=tonos-cli

#./msig.sh test
# top up msig with USDT

wallet="$(cat test.msig.addr | grep "Raw address" | awk '{print $3}')"

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
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json > log.log
}


METADUES_ROOT_ADDRESS=$(cat $CONTRACT_NAME.addr)
USDT_ROOT="0:c5f5a0f97da30c303808acac50eff22d81f4b268745cb43f352495711fe052b1"

##Deploy account
$tos --url $NETWORK  call $wallet  submitTransaction "{\"dest\":\"$METADUES_ROOT_ADDRESS\",\"value\":200000000,\"bounce\":false,\"allBalance\":false,\"payload\":\"te6ccgEBAQEABgAACAOxbTU=\"}" --abi ../../ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.abi.json --sign test.msig.keys.json
account_address=$(tonos-cli -j run $METADUES_ROOT_ADDRESS accountOf "{\"owner_address_\":\"$wallet\"}" --abi ../abi/EverduesRoot.abi.json | jq -r .account)

##top up account wallet
account_wallet=$($tos --url $NETWORK run $USDT_ROOT  walletOf "{\"answerId\":\"0\",\"walletOwner\":\"$account_address\"}" --abi ../../ton-eth-bridge-token-contracts/build/TokenRoot.abi.json|grep value0|awk '{print $2}' | tr -d \")

owner_wallet=$($tos --url $NETWORK run $USDT_ROOT  walletOf "{\"answerId\":\"0\",\"walletOwner\":\"$wallet\"}" --abi ../../ton-eth-bridge-token-contracts/build/TokenRoot.abi.json | grep value0 | awk '{print $2}')

payload=$(tonos-cli --url $NETWORK body transferToWallet "{\"amount\": \"10\", \"recipientTokenWallet\": \"$account_wallet\", \"remainingGasTo\": \"$wallet\",\"notify\": \"true\",\"payload\": \"te6ccgEBAQEAAgAAAA==\"}"  --abi ../../ton-eth-bridge-token-contracts/build/TokenWallet.abi.json | grep 'Message body:' | awk '{print $3}')

$tos --url $NETWORK  call $wallet  submitTransaction "{\"dest\":$owner_wallet,\"value\":200000000,\"bounce\":false,\"allBalance\":false,\"payload\":\"$payload\"}" --abi ../../ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.abi.json --sign test.msig.keys.json

##Check account balance
sleep 10

$tos --url $NETWORK run $account_address  wallets_mapping "{}" --abi ../abi/EverduesAccount.abi.json

##Deploy service
tonos-cli --url $NETWORK call $METADUES_ROOT_ADDRESS  deployService "{\"service_params\":\"te6ccgEBBwEAtwABa4AbmUiTj4jAIB7gbWilvUp9Mdxf9W0+LFUhqoCKyU3O0eAAAAAAAAAAAAAAAAAgbMgAAAAD0AEEAAYFBAIBQ4AaqpoiehC9jd11Xg0kTEEvFKWi0oimoYdhTRY13+72U7ADAAhEZUZpAFxRbVl1NVYzcXRmejNtRENRQVd3WkN3Q21lY014Mm5wZm83Yk5odEZSTnVVTFlXABZsaWItdGVzdDJ2YQAcdGlwMy1saWItdGVzdDU=\"}" --abi ../abi/EverduesRoot.abi.json
service_adress=$(tonos-cli -j run $METADUES_ROOT_ADDRESS accountOf "{\"owner_address_\":\"$wallet\",\"service_name_\":\"lib-test\"}" --abi ../abi/EverduesRoot.abi.json | jq -r .account)


##Deploy Subscription
tonos-cli --url $NETWORK body deploySubscription "{\"service_address\": \"$service_adress\", \"identificator\": \"te6ccgEBAQEAAgAAAA==\"}" --abi ../abi/EverduesRoot.abi.json

##Check account balance #2
sleep 120
$tos --url $NETWORK run $account_address  wallets_mapping "{}" --abi ../abi/EverduesAccount.abi.json
