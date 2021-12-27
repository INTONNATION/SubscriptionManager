#!/bin/bash

set -xe

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

# mWalletTVC
mwalletTvc=`cat ../abi/m$1TokenWallet.tvc | base64 $prefix`

# Addresses
mRootAddr=`cat m$1RootTokenContract.addr`
RootAddr=`cat $1RootTokenContract.addr`
mConvertWalletAddrAddr=`cat m$1ConvertWalletAddr.addr`
ConvertWalletAddr=`cat $1ConvertWalletAddr.addr`

# ABIs
mRootTokenContract=`cat ../abi/mRootTokenContract.abi.json | jq -c . | base64 $prefix`
mTONTokenWalletContract=`cat ../abi/mTONTokenWalletContract.abi.json | jq -c . | base64 $prefix `
RootTokenContract=`cat ../abi/RootTokenContract.abi.json | jq -c . | base64 $prefix`
TONTokenWalletContract=`cat ../abi/TONTokenWalletContract.abi.json | jq -c . | base64 $prefix`

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

configName="configConvert$1"
configAddr=$(cat ./$configName.addr)
echo $configAddr

tonos-cli --url $NETWORK call $configAddr setTvcWallet "{\"tvcWalletINPUT\": \"$mwalletTvc\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setmRootAddr "{\"mRootAddrINPUT\": \"$mRootAddr\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setRootAddr "{\"RootAddrINPUT\": \"$RootAddr\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setmConvertWalletAddrAddr "{\"mConvertWalletAddrAddrINPUT\": \"$mConvertWalletAddrAddr\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setConvertWalletAddr "{\"ConvertWalletAddrINPUT\": \"$ConvertWalletAddr\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbimRootTokenContract "{\"mRootTokenContractINPUT\": \"$mRootTokenContract\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbimTONTokenWalletContract "{\"mTONTokenWalletContractINPUT\": \"$mTONTokenWalletContract\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiRootTokenContract "{\"RootTokenContractINPUT\": \"$RootTokenContract\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiTONTokenWalletContract "{\"TONTokenWalletContractINPUT\": \"$TONTokenWalletContract\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json