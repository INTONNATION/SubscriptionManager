#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$MAINNET

tonos-cli config --url $NETWORK

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
tonos-cli --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":2000000000, \"bounce\":\"false\"}"
}

function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function genseed {
tonos-cli genphrase > ./envs/$1.seed
}

function genpubkey {
tonos-cli genpubkey "$1" > $2.pub
}

function genkeypair {
tonos-cli getkeypair -o ./envs/$1.keys.json -p "$2"
}

function genaddr {
tonos-cli genaddr ../abi/$1.tvc --abi ../abi/$1.abi.json --setkey ./envs/$2.keys.json > log.log
}

function deploy {
params=$2-$1
genseed $params
seed=`cat ./envs/$params.seed | grep -o '".*"' | tr -d '"'`
echo "DeBot seed - $seed"
genpubkey "$seed" "client"
pub=`cat $params.pub | grep "Public key" | awk '{print $3}'`
echo "Debot pubkey - $pub"
genkeypair "$params" "$seed"
echo GENADDR $1 ----------------------------------------------
genaddr $1 $params
CONTRACT_ADDRESS=$(get_address)
echo -n $CONTRACT_ADDRESS > ./envs/$params.addr
echo GIVER $1 ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
# if [[ `$2` = "main" ]]; 
# then
#     owner=`cat prod-multisig.msig.addr| grep "Raw address" | awk '{print $3}'`
# else
#     owner=`cat dev-single.msig.addr| grep "Raw address" | awk '{print $3}'`    
# fi
owner=`cat dev-single.msig.addr| grep "Raw address" | awk '{print $3}'`    
tonos-cli --url $NETWORK deploy ../abi/$1.tvc "{\"initial_owner\":\"$owner\"}" --sign ./envs/$params.keys.json --abi ../abi/$1.abi.json
giver $CONTRACT_ADDRESS
# Categories
categories=[\"Telegram\",\"Gambling\",\"Rentals\",\"Content\",\"Media\",\"Music\",\"Goods\",\"Education\",\"Software\",\"Membership\",\"DeFi\",\"NFT\",\"Games\",\"Other\"]

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

# Top up wallet
fee_proxy=`tonos-cli -j run $CONTRACT_ADDRESS fee_proxy_address '{}' --abi ../abi/EverduesRoot.abi.json | jq  -r .fee_proxy_address`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $fee_proxy --value 10T --bounce true --allBalance false

# Set TVCs
message=`tonos-cli -j body setCodePlatform "{\"codePlatformInput\":\"$platformCode\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeEverduesAccount "{\"codeEverduesAccountInput\":\"$accountCode\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeSubscription "{\"codeSubscriptionInput\":\"$subscriptionCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeIndex "{\"codeIndexInput\":\"$indexCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeService "{\"codeServiceInput\":\"$subscriptionServiceCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCodeFeeProxy "{\"codeFeeProxyInput\":\"$feeProxyCode\"}"  --abi ../abi/$1.abi.json  | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
#
## SET ABIs
message=`tonos-cli -j body setAbiPlatformContract "{\"abiPlatformContractInput\":\"$abiPlatformContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiEverduesAccountContract "{\"abiEverduesAccountContractInput\":\"$abiEverduesAccountContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiEverduesRootContract "{\"abiEverduesRootContractInput\":\"$abiEverduesRootContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiTIP3RootContract "{\"abiTIP3RootContractInput\":\"$abiTIP3RootContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiTIP3TokenWalletContract "{\"abiTIP3TokenWalletContractInput\":\"$abiTIP3TokenWalletContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiServiceContract "{\"abiServiceContractInput\":\"$abiServiceContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiIndexContract "{\"abiIndexContractInput\":\"$abiIndexContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiSubscriptionContract "{\"abiSubscriptionContractInput\":\"$abiSubscriptionContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAbiFeeProxyContract "{\"abiFeeProxyContractInput\":\"$abiFeeProxyContract\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
# set settings
message=`tonos-cli -j body deployFeeProxy "{\"currencies\":[\"0:57b268d5c4e2e43a25e53d2d092a5457d8ddd8f6e9ffb6c1dec02b27bfe62105\",\"0:a519f99bb5d6d51ef958ed24d337ad75a1c770885dcd42d51d6663f9fcdacfb2\"]}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 4T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setFees "{\"service_fee_\":\"2\",\"subscription_fee_\":\"0\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body installOrUpgradeMTDSRevenueDelegationAddress "{\"revenue_to\":\"0:fa32cb6feb67675c9b3cf0bbe7327f23c683e01164ebd365a5fde39813d965df\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body installOrUpgradeMTDSRootAddress "{\"mtds_root_\":\"0:57b268d5c4e2e43a25e53d2d092a5457d8ddd8f6e9ffb6c1dec02b27bfe62105\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body installOrUpgradeDexRootAddresses "{\"dex_root\":\"0:5eb5713ea9b4a0f3a13bc91b282cde809636eb1e68d2fcb6427b9ad78a5a9008\",\"tip3_to_ever\":\"0:4d7dbf7a62cf329bf74260c66028e2381b58cce96b13acc8524dda2358ee88c5\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body installOrUpgradeWEVERRoot "{\"wever_root_\":\"0:a49cd4e158a9a15555e624759e2e4e766d22600b7800d891e46f9291f044a93d\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setDeployServiceParams "{\"currency_root\": \"0:a519f99bb5d6d51ef958ed24d337ad75a1c770885dcd42d51d6663f9fcdacfb2\", \"lock_amount\":\"100\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setAccountGasThreshold "{\"account_threshold_\": \"4000000000\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setCategories "{\"categoriesInput\": $categories}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setGasCompenstationProportion "{\"service_gas_compenstation_\": \"100\", \"subscription_gas_compenstation_\":\"0\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
message=`tonos-cli -j body setRecurringPaymentGas "{\"recurring_payment_gas_\":\"400000000\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
}

deploy $CONTRACT_NAME $1
CONTRACT_ADDRESS=$(cat ./envs/$1-$CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
