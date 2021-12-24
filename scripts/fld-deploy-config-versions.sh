#!/bin/bash

set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94

SafeMultisigWalletABI="../abi/SafeMultisigWallet.abi.json"
contract_name="configVersions"
contract_abi="../abi/$contract_name.abi.json"

tondev sol compile ../contracts/$contract_name.sol -o ../abi;
tvc="../abi/$contract_name.tvc"
contract_address=`tonos-cli genaddr $tvc $contract_abi --genkey $contract_name.keys.json | grep 'Raw address' | awk '{print $NF}'`

# Change gen key to set key if needed
echo $contract_address > $contract_name.addr

tonos-cli --url $NETWORK call --abi ../abi/local_giver.abi.json $giver sendGrams "{\"dest\":\"$contract_address\",\"amount\":20000000000}"
tonos-cli --url $NETWORK deploy $tvc {} --abi $contract_abi --sign $contract_name.keys.json 
