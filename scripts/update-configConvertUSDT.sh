#!/bin/bash

set -xe

if [[ $1 = "linux" ]]; then
    prefix="-w0"
fi

# mUSDT TVC
mUSDTwalletTvc=`cat ../abi/mUSDTTokenWallet.tvc | base64 $prefix`

# Addresses
mUSDTRootAddr=`cat mUSDTRootTokenContract.addr`
USDTRootAddr=`cat USDTRootTokenContract.addr`
mUSDTConvertWallet=`cat mUSDTConvertWallet.addr`
USDTConvertWallet=`cat USDTConvertWallet.addr`

# ABIs
mRootTokenContract=`cat ../abi/mRootTokenContract.abi.json | base64 $prefix`
mTONTokenWallet=`cat ../abi/mTONTokenWallet.abi.json | base64 $prefix `
RootTokenContract=`cat ../abi/RootTokenContract.abi.json | base64 $prefix`
TONTokenWallet=`cat ../abi/TONTokenWallet.abi.json | base64 $prefix`

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

configName='configConvertUSDT'
configAddr=$(cat ./$configName.addr)
echo $configAddr

tonos-cli --url $NETWORK call $configAddr setTvcWallet "{\"tvcWalletINPUT\": \"$mUSDTwalletTvc\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setmUSDTRootAddr "{\"mUSDTRootAddrINPUT\": \"$mUSDTRootAddr\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setUSDTRootAddr "{\"USDTRootAddrINPUT\": \"$USDTRootAddr\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setmUSDTConvertWallet "{\"mUSDTConvertWalletINPUT\": \"$mUSDTConvertWallet\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setUSDTConvertWallet "{\"USDTConvertWalletINPUT\": \"$USDTConvertWallet\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbimRootTokenContract "{\"mRootTokenContractINPUT\": \"$mRootTokenContract\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbimTONTokenWallet "{\"mTONTokenWalletINPUT\": \"$mTONTokenWallet\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiRootTokenContract "{\"RootTokenContractINPUT\": \"$RootTokenContract\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json
tonos-cli --url $NETWORK call $configAddr setAbiTONTokenWallet "{\"TONTokenWalletINPUT\": \"$TONTokenWallet\"}" --abi ../abi/$configName.abi.json --sign $configName.keys.json