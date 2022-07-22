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
platformCode=$(tvm_linker decode --tvc ../abi/Platform.tvc | grep code: | awk '{ print $2 }')
metaduesAccountCode=$(tvm_linker decode --tvc ../abi/EverduesAccount.tvc | grep code: | awk '{ print $2 }')
subscriptionCode=$(tvm_linker decode --tvc  ../abi/Subscription.tvc | grep code: | awk '{ print $2 }')
subscriptionIndexCode=$(tvm_linker decode --tvc  ../abi/SubscriptionIndex.tvc | grep code: | awk '{ print $2 }')
subscriptionServiceCode=$(tvm_linker decode --tvc  ../abi/SubscriptionService.tvc | grep code: | awk '{ print $2 }')
subscriptionServiceIndexCode=$(tvm_linker decode --tvc  ../abi/SubscriptionServiceIndex.tvc | grep code: | awk '{ print $2 }')
subscriptionidentificatorIndexCode=$(tvm_linker decode --tvc  ../abi/SubscriptionIdentificatorIndex.tvc | grep code: | awk '{ print $2 }')
feeProxyCode=$(tvm_linker decode --tvc  ../abi/EverduesFeeProxy.tvc | grep code: | awk '{ print $2 }')
serviceIdentificator=$(tvm_linker decode --tvc  ../abi/SubscriptionServiceIdentificatorIndex.tvc | grep code: | awk '{ print $2 }')

#ABI
abiPlatformContract=$(cat ../abi/Platform.abi.json | jq -c .| base64 $prefix)
abiSubscriptionContract=$(cat ../abi/Subscription.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIndexContract=$(cat ../abi/SubscriptionIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIdentificatorIndexContract=$(cat ../abi/SubscriptionIdentificatorIndex.abi.json | jq -c .| base64 $prefix)

# Set TVCs
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeSubscription "{\"codeSubscriptionInput\":\"$subscriptionCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeSubscriptionIndex "{\"codeSubscriptionIndexInput\":\"$subscriptionIndexCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeSubscriptionIdentificatorIndex "{\"codeSubscriptionIdentificatorIndexInput\":\"$subscriptionidentificatorIndexCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
#
## SET ABIs
message=`tonos-cli -j body setAbiSubscriptionContract "{\"abiSubscriptionContractInput\":\"$abiSubscriptionContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiSubscriptionIndexContract "{\"abiSubscriptionIndexContractInput\":\"$abiSubscriptionIndexContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiSubscriptionIdentificatorIndexContract "{\"abiSubscriptionIdentificatorIndexContractInput\":\"$abiSubscriptionIdentificatorIndexContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setVersion "{}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
}

deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
