#!/bin/bash

set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net1.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$MAINNET

SafeMultisigWalletABI="../../ton-labs-contracts/solidity/bridgemultisig/BridgeMultisigWallet.abi.json"
SafeMultisigWalletTVC="../../ton-labs-contracts/solidity/bridgemultisig/BridgeMultisigWallet.tvc"

giver=0:705e21688486a905a2f83f940dfbafcd4d319cff31d4189ebf4483e16553fa33

seed=`cat $1.msig.seed | grep -o '".*"' | tr -d '"'`
echo "seed - $seed"
tonos-cli getkeypair $1.msig.keys.json "$seed"
tonos-cli genaddr $SafeMultisigWalletTVC $SafeMultisigWalletABI --setkey $1.msig.keys.json --wc 0 > $1.msig.addr
addr=`cat $1.msig.addr | grep "Raw address" | awk '{print $3}'`
echo "addr $addr"

function giver {
tonos-cli --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":10000000000, \"bounce\":\"false\"}"
}

giver $addr

tonos-cli deploy $SafeMultisigWalletTVC "{\"owners\":[\"0x47a1ba2297684c89ad92f1660d0bf0d62c7cdc4259bdc7cc74eff345b8d424bc\",\"0x0d5e2a22a83bc210b810a25b9c15a23a146a192d3a62b730be74b3423bd1bf77\",\"0x5279ec9760c23375db7a81a3da279b609c84c0ead74831700db2d1c7f6c8aa81\"],\"reqConfirms\":2}" --abi $SafeMultisigWalletABI --sign $1.msig.keys.json --wc 0
tonos-cli account $addr
