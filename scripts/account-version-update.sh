#!/bin/bash
 set -xe

 LOCALNET=http://127.0.0.1
 DEVNET=https://net1.ton.dev
 MAINNET=https://main.ton.dev
 FLD=https://gql.custler.net
 NETWORK=$MAINNET

 if [[ `uname` = "Linux" ]]; then
     prefix="-w0"
 fi



 CONTRACT_NAME=EverduesRoot




#Update account
message=$(tonos-cli --json body forceUpgradeAccount "{\"account_address\":\"$1\"}"  --abi ../abi/EverduesRoot.abi.json | jq -r .Message)

echo $message

tonos-cli callex submitTransaction 0:aba04121a9e69a0140e072ce770ddb012aa828279b1a7c2e6d6f1dbe38e4ceb0 ../abi/SafeMultisigWallet.abi.json devnet.msig.keys.json --dest $(cat EverduesRoot.addr) --value 1T --bounce true --allBalance false --payload "$message"