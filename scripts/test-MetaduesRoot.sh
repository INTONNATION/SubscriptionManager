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



CONTRACT_NAME=MetaduesRoot
tos=tonos-cli
wallet="0:76f1ff37f7d17e49a5bc5018aba10145ede9e112f52fe1be325d1641c6d8c92d"
passpharse="ice interest boring awesome poem quick okay match purity narrow crash kick"


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
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey $passpharse > log.log
}



METADUES_ROOT_ADDRESS=$(cat $CONTRACT_NAME.addr)
MTDS_ROOT="0:da294485c0a26f3014d3e65ae954094ebdcc6846dc761a266592a0dde82d61f5"
USDT_ROOT="0:9975e3cd0cdfa06d5b1e15aa19b224edf9dd873ba983f17067a67d1db8cd8f07"



##Deploy account
$tos --url $NETWORK  call $wallet  submitTransaction "{"dest":"$METADUES_ROOT_ADDRESS","value":200000000,"bounce":false,"allBalance":false,"payload":"te6ccgEBAQEABgAACAOxbTU="}" --abi ~/Desktop/rust_multisig/ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.abi.json --sign $passpharse
genaddr MetaduesAccount
account_address=$(get_address)

##top up account wallet
account_wallet=$($tos --url $NETWORK run $USDT_ROOT  walletOf "{\"answerId\":\"0\",\"walletOwner\":\"$account_address\"}" --abi ../build/TokenRoot.abi.json|grep value0|awk '{print $2}')
owner_wallet=$($tos --url $NETWORK run $USDT_ROOT  walletOf "{\"answerId\":"\0\","\walletOwner\":\"$wallet\"}" --abi ../build/TokenRoot.abi.json|grep value0|awk '{print $2}')
payload=$(tonos-cli  --url https://gql.custler.net  body transferToWallet "{\"amount\": \"10\", \"recipientTokenWallet\": \"$account_wallet\", \"remainingGasTo\": \"$wallet\",\"notify\": \"true\",\"payload\": \"te6ccgEBAQEAAgAAAA==\"}"  --abi ../../ton-eth-bridge-token-contracts/build/TokenWallet.abi.json|grep "Message body:"|awk '{print $3}')

$tos --url $NETWORK  call $wallet  submitTransaction "{"dest":"$owner_wallet","value":200000000,"bounce":false,"allBalance":false,"$payload":"te6ccgEBAQEABgAACAOxbTU="}" --abi ~/Desktop/rust_multisig/ton-labs-contracts/solidity/safemultisig/SafeMultisigWallet.abi.json --sign $passpharse

##Check account balance
$tos --url $NETWORK run $account_adress  wallets_mapping "{}" --abi ../abi/MetaduesAccount.abi.json



##Deploy service
tonos-cli  --url https://gql.custler.net  call $METADUES_ROOT_ADDRESS  deployService "{\"service_params\":\"te6ccgEBBwEAtwABa4AbmUiTj4jAIB7gbWilvUp9Mdxf9W0+LFUhqoCKyU3O0eAAAAAAAAAAAAAAAAAgbMgAAAAD0AEEAAYFBAIBQ4AaqpoiehC9jd11Xg0kTEEvFKWi0oimoYdhTRY13+72U7ADAAhEZUZpAFxRbVl1NVYzcXRmejNtRENRQVd3WkN3Q21lY014Mm5wZm83Yk5odEZSTnVVTFlXABZsaWItdGVzdDJ2YQAcdGlwMy1saWItdGVzdDU=\"}" --abi ../abi/MetaduesRoot.abi.json
genaddr SubscriptionService
service_adress=$(get_address)


##Deploy Subscription
tonos-cli  --url https://gql.custler.net  body deploySubscription "{\"service_address\": \"$service_adress\", \"identificator\": \"te6ccgEBAQEAAgAAAA==\"}" --abi ../abi/MetaduesRoot.abi.json

##Check account balance #2
sleep(120)
$tos --url $NETWORK run $account_adress  wallets_mapping "{}" --abi ../abi/MetaduesAccount.abi.json

}
