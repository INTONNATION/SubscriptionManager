#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$DEVNET

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

tondev sol compile ../contracts/EverduesRoot.sol -o ../abi;
tondev sol compile ../contracts/EverduesAccount.sol -o ../abi;
tondev sol compile ../contracts/Platform.sol -o ../abi;
tondev sol compile ../contracts/Subscription.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionService.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionServiceIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionServiceIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/EverduesFeeProxy.sol -o ../abi;

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
platformTvc=$(cat ../abi/Platform.tvc | base64 $prefix)
metaduesAccountTvc=$(cat ../abi/EverduesAccount.tvc | base64 $prefix)
subscriptionTvc=$(cat ../abi/Subscription.tvc | base64 $prefix)
subscriptionIndexTvc=$(cat ../abi/SubscriptionIndex.tvc | base64 $prefix)
subscriptionServiceTvc=$(cat ../abi/SubscriptionService.tvc | base64 $prefix)
subscriptionServiceIndexTvc=$(cat ../abi/SubscriptionServiceIndex.tvc | base64 $prefix)
subscriptionidentificatorIndexTvc=$(cat ../abi/SubscriptionIdentificatorIndex.tvc | base64 $prefix)
feeProxyTvc=$(cat ../abi/EverduesFeeProxy.tvc | base64 $prefix)
serviceIdentificator=$(cat ../abi/SubscriptionServiceIdentificatorIndex.tvc | base64 $prefix)

#ABI
abiPlatformContract=$(cat ../abi/Platform.abi.json | jq -c .| base64 $prefix)
abiEverduesAccountContract=$(cat ../abi/EverduesAccount.abi.json | jq -c .| base64 $prefix)
abiEverduesRootContract=$(cat ../abi/EverduesRoot.abi.json  | jq 'del(.fields)' | jq -c .| base64 $prefix)
abiTIP3RootContract=$(cat ../ton-eth-bridge-token-contracts/build/TokenRoot.abi.json | jq -c .| base64 $prefix)
abiTIP3TokenWalletContract=$(cat ../ton-eth-bridge-token-contracts/build/TokenWallet.abi.json | jq -c .| base64 $prefix)
abiServiceContract=$(cat ../abi/SubscriptionService.abi.json | jq -c .| base64 $prefix)
abiServiceIndexContract=$(cat ../abi/SubscriptionServiceIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionContract=$(cat ../abi/Subscription.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIndexContract=$(cat ../abi/SubscriptionIndex.abi.json | jq -c .| base64 $prefix)
abiSubscriptionIdentificatorIndexContract=$(cat ../abi/SubscriptionIdentificatorIndex.abi.json | jq -c .| base64 $prefix)
abiFeeProxyContract=$(cat ../abi/EverduesFeeProxy.abi.json | jq -c .| base64 $prefix)
abiServiceIdentificator=$(cat ../abi/SubscriptionServiceIdentificatorIndex.abi.json | jq -c .| base64 $prefix)

# Set TVCs
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setTvcSubscription "{\"tvcSubscriptionInput\":\"$subscriptionTvc\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setTvcSubscriptionIndex "{\"tvcSubscriptionIndexInput\":\"$subscriptionIndexTvc\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setTvcSubscriptionIdentificatorIndex "{\"tvcSubscriptionIdentificatorIndexInput\":\"$subscriptionidentificatorIndexTvc\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
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
message=`tonos-cli -j body upgradeFeeProxy "{}"  --abi ../abi/EverduesRoot.abi.json | jq -r .Message`
tonos-cli callex submitTransaction $owner ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $CONTRACT_ADDRESS --value 3T --bounce true --allBalance false --payload "$message"
}

deploy $CONTRACT_NAME
CONTRACT_ADDRESS=$(cat $CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
