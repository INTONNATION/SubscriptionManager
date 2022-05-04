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

function deploy {
CONTRACT_ADDRESS=`cat EverduesRoot.addr`
owner=`cat single.msig.addr| grep "Raw address" | awk '{print $3}'`

# TVC
platformTvc=$(cat ../abi/Platform.tvc | base64 $prefix)
subscriptionServiceTvc=$(cat ../abi/SubscriptionService.tvc | base64 $prefix)
subscriptionServiceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64 $prefix)
serviceIdentificator=$(cat ../abi/SubscriptionServiceIdentificatorIndex.tvc | base64 $prefix)

#ABI
abiPlatformContract=$(cat ../abi/Platform.abi.json | jq -c .| base64 $prefix)
abiServiceContract=$(cat ../abi/SubscriptionService.abi.json | jq -c .| base64 $prefix)
abiServiceIndexContract=$(cat ../abi/SubscriptionServiceIndex.abi.json | jq -c .| base64 $prefix)
abiServiceIdentificator=$(cat ../abi/SubscriptionServiceIdentificatorIndex.abi.json | jq -c .| base64 $prefix)

# Set TVCs
message=`tonos-cli -j body setTvcSubscriptionService "{\"tvcSubscriptionServiceInput\":\"$subscriptionServiceTvc\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setTvcSubscriptionServiceIndex "{\"tvcSubscriptionServiceIndexInput\":\"$subscriptionServiceIndexTvc\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setTvcSubscriptionServiceIdentificatorIndex "{\"tvcSubscriptionServiceIdentificatorIndexInput\":\"$serviceIdentificator\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
#
## SET ABIs
message=`tonos-cli -j body setAbiServiceContract "{\"abiServiceContractInput\":\"$abiServiceContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiServiceIndexContract "{\"abiServiceIndexContractInput\":\"$abiServiceIndexContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiServiceIdentificatorIndexContract "{\"abiServiceIdentificatorIndexContractInput\":\"$abiServiceIdentificator\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setVersion "{}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
}
deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
