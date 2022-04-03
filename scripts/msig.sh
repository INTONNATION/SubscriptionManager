#!/bin/bash

set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net1.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$DEVNET

SafeMultisigWalletABI="../../ton-labs-contracts/solidity/bridgemultisig/BridgeMultisigWallet.abi.json"
SafeMultisigWalletTVC="../../ton-labs-contracts/solidity/bridgemultisig/BridgeMultisigWallet.tvc"

giver=0:705e21688486a905a2f83f940dfbafcd4d319cff31d4189ebf4483e16553fa33

tonos-cli genphrase > $1.msig.seed
seed=`cat $1.msig.seed | grep -o '".*"' | tr -d '"'`
echo "seed - $seed"
tonos-cli genpubkey "$seed" > $1.msig.pub
pub=`cat $1.msig.pub | grep "Public key" | awk '{print $3}'`
echo "pub - $pub"
tonos-cli getkeypair $1.msig.keys.json "$seed"
tonos-cli genaddr $SafeMultisigWalletTVC $SafeMultisigWalletABI --setkey $1.msig.keys.json --wc 0 > $1.msig.addr
addr=`cat $1.msig.addr | grep "Raw address" | awk '{print $3}'`
echo "addr $addr"

function giver {
tonos-cli --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":10000000000, \"bounce\":\"false\"}"
}

giver $addr

tonos-cli deploy $SafeMultisigWalletTVC "{\"owners\":[\"0x$pub\"],\"reqConfirms\":1}" --abi $SafeMultisigWalletABI --sign $1.msig.keys.json --wc 0
tonos-cli account $addr
