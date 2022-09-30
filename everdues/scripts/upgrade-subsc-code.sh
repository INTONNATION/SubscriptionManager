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

# TVC
platformCode=$(tvm_linker decode --tvc ../abi/Platform.tvc | grep code: | awk '{ print $2 }')
accountCode=$(tvm_linker decode --tvc ../abi/EverduesAccountV1.tvc | grep code: | awk '{ print $2 }')
subscriptionCode=$(tvm_linker decode --tvc  ../abi/EverduesSubscriptionV1.tvc | grep code: | awk '{ print $2 }')
subscriptionServiceCode=$(tvm_linker decode --tvc  ../abi/EverduesServiceV1.tvc | grep code: | awk '{ print $2 }')
indexCode=$(tvm_linker decode --tvc  ../abi/Index.tvc | grep code: | awk '{ print $2 }')
feeProxyCode=$(tvm_linker decode --tvc  ../abi/EverduesFeeProxy.tvc | grep code: | awk '{ print $2 }')

#ABI
abiPlatformContract=$(cat ../abi/Platform.abi.json | jq -c .| base64 $prefix)
abiEverduesAccountContract=$(cat ../abi/EverduesAccountV1.abi.json | jq -c .| base64 $prefix)
abiEverduesRootContract=$(cat ../abi/EverduesRoot.abi.json  | jq 'del(.fields)' | jq -c .| base64 $prefix)
abiTIP3RootContract=$(cat ../../ton-eth-bridge-token-contracts/build/TokenRoot.abi.json | jq -c .| base64 $prefix)
abiTIP3TokenWalletContract=$(cat ../../ton-eth-bridge-token-contracts/build/TokenWallet.abi.json | jq -c .| base64 $prefix)
abiServiceContract=$(cat ../abi/EverduesServiceV1.abi.json | jq -c .| base64 $prefix)
abiIndexContract=$(cat ../abi/Index.abi.json | jq -c .| base64 $prefix)
abiSubscriptionContract=$(cat ../abi/EverduesSubscriptionV1.abi.json | jq -c .| base64 $prefix)
abiFeeProxyContract=$(cat ../abi/EverduesFeeProxy.abi.json | jq -c .| base64 $prefix)

# Set TVCs
message=`tonos-cli -j body setCodeSubscription "{\"codeSubscriptionInput\":\"$subscriptionCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
#
## SET ABIs
message=`tonos-cli -j body setAbiSubscriptionContract "{\"abiSubscriptionContractInput\":\"$abiSubscriptionContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
echo $CONTRACT_ADDRESS
}

deploy $CONTRACT_NAME $1
