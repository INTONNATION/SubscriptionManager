#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=net.ton.dev
MAINNET=https://mainnet.evercloud.dev/a0b43df808ec4afe8d75ef8bdc3054d3
FLD=https://gql.custler.net
NETWORK=$MAINNET

tonos-cli config --url $NETWORK --lifetime 60

everdev sol set --compiler 0.64.0
everdev sol set --linker 0.16.4


everdev sol version
everdev tonos-cli version

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

rm -rf node_modules
./compile.sh

CONTRACT_NAME=EverduesRoot

function deploy {
CONTRACT_ADDRESS=`cat ./envs/$2-EverduesRoot.addr`
if [[ $2 == "prod" ]]; then
    owner=`cat prod-multisig.msig.addr`
else
    owner=`cat dev-single.msig.addr`
fi
code=`tvm_linker decode --tvc ../abi/EverduesRoot.tvc | grep code: | awk '{ print $2 }'`
message=`tonos-cli -j body upgrade "{\"code\":\"$code\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 5T --bounce true --allBalance false --payload "$message"
# Categories
categories=[\"Crypto\",\"Content\",\"Membership\",\"Software\",\"Infrastructure\",\"Investments\",\"Data\",\"Other\"]

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

#DELETE IN NEXT RELEASE
tonos-cli call $CONTRACT_ADDRESS eraseMappings "{}" --abi ../abi/$1.abi.json
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
#message=`tonos-cli -j body deployFeeProxy "{\"currencies\":[\"0:57b268d5c4e2e43a25e53d2d092a5457d8ddd8f6e9ffb6c1dec02b27bfe62105\",\"0:a519f99bb5d6d51ef958ed24d337ad75a1c770885dcd42d51d6663f9fcdacfb2\"]}" --abi ../abi/$1.abi.json | jq -r .Message`
#tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 4T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body setFees "{\"service_fee_\":\"0\",\"subscription_fee_\":\"0\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeDUESRevenueDelegationAddress "{\"revenue_to\":\"0:fa32cb6feb67675c9b3cf0bbe7327f23c683e01164ebd365a5fde39813d965df\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeDUESRootAddress "{\"dues_root\":\"0:57b268d5c4e2e43a25e53d2d092a5457d8ddd8f6e9ffb6c1dec02b27bfe62105\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeDexRootAddresses "{\"dex_root\":\"0:5eb5713ea9b4a0f3a13bc91b282cde809636eb1e68d2fcb6427b9ad78a5a9008\",\"tip3_to_ever\":\"0:4d7dbf7a62cf329bf74260c66028e2381b58cce96b13acc8524dda2358ee88c5\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeWEVERRoot "{\"wever_root_\":\"0:a49cd4e158a9a15555e624759e2e4e766d22600b7800d891e46f9291f044a93d\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body setDeployServiceParams "{\"currency_root\": \"0:95abb293d0c9ef76688aace781ca655ea2a828d925d081e5ccc4ff5bcb49c206\", \"lock_amount\":\"1000000\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body setAccountGasThreshold "{\"account_threshold_\": \"4000000000\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body setCategories "{\"categoriesInput\": $categories}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body setGasCompenstationProportion "{\"service_gas_compenstation_\": \"100\", \"subscription_gas_compenstation_\":\"0\"}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body setRecurringPaymentGas "{\"recurring_payment_gas_\":\"400000000\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeCrossChainContractsAddresses "{\"chain_id\":\"56\",\"contract_address\":\"0xa458e719dFEd474ed29B4bC5498111Db50acAa74\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeCrossChainContractsAddresses "{\"chain_id\":\"1\",\"contract_address\":\"0x961d8d0eE1855e600816Feb98BfcE17202aDCC2f\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"


message=`tonos-cli -j body installOrUpgradeCrossChainContractsAddresses "{\"chain_id\":\"11155111\",\"contract_address\":\"0x41fde22032d9044ebfe888cda819072fe108f7d4\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeCrossChainContractsAddresses "{\"chain_id\":\"137\",\"contract_address\":\"0xE0184d6c2c75964a08B66081ECDDd0Ab5F45463F\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeExternalTokensAddresses "{\"chain_id\":\"56\",\"supported_tokens\":[\"0x55d398326f99059ff775485246999027b3197955\",\"0xe9e7cea3dedca5984780bafc599bd69add087d56\",\"0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d\",\"0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3\"]}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeExternalTokensAddresses "{\"chain_id\":\"11155111\",\"supported_tokens\":[\"0x0Bd5F04B456ab34a2aB3e9d556Fe5b3A41A0BC8D\"]}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeExternalTokensAddresses "{\"chain_id\":\"1\",\"supported_tokens\":[\"0xdac17f958d2ee523a2206206994597c13d831ec7\",\"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48\",\"0x4fabb145d64652a948d72533023f6e7a623c7c53\",\"0x6b175474e89094c44da98b954eedeac495271d0f\"]}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeExternalTokensAddresses "{\"chain_id\":\"137\",\"supported_tokens\":[\"0xc2132d05d31c914a87c6611c10748aeb04b58e8f\",\"0x2791bca1f2de4661ed88a30c99a7a9449aa84174\",\"0x9c9e5fd8bbc25984b178fdce6117defa39d2db39\",\"0x8f3cf7ad23cd3cadbd9735aff958023239c6a063\"]}" --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

message=`tonos-cli -j body installOrUpgradeEverDuesWrappedTokens "{\"tip3_root\":\"0:9e7cd76a84c20ae013348de6709d954ef65f3679c1ce565dcb6ec1ac8add57fa\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"

if [[ $2 == "prod" ]]; then
    message=`tonos-cli -j body installOrUpgradeWatcherAddress "{\"watcher_address\":\"0:a38e7e90fd54cccd8eabf499d25dec8a36ef6bb8317e85a566778138ede91192\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
    tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
    echo "Variables are equal"
else 
    message=`tonos-cli -j body installOrUpgradeWatcherAddress "{\"watcher_address\":\"0:aba04121a9e69a0140e072ce770ddb012aa828279b1a7c2e6d6f1dbe38e4ceb0\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
    tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
fi

evm_abi=`cat ../abi/RecurringPayments.json | jq .abi | jq -c .| base64 $prefix`
message=`tonos-cli -j body setAbiEVMRecurringContract "{\"abiEVMRecurringContractInput\":\"${evm_abi}\"}"  --abi ../abi/$1.abi.json | jq -r .Message`
tonos-cli callx -m submitTransaction --addr $owner --abi ../abi/SafeMultisigWallet.abi.json --keys owner.msig.keys.json --dest $CONTRACT_ADDRESS --value 1T --bounce true --allBalance false --payload "$message"
}

deploy $CONTRACT_NAME $1
## Upgrade all deployed contracts
#npm i
#node upgrade-all-service-contracts.js $1
#node upgrade-all-account-contracts.js $1
#node upgrade-all-subscription-contracts.js $1

CONTRACT_ADDRESS=$(cat ./envs/$1-$CONTRACT_NAME.addr)

echo $CONTRACT_ADDRESS
