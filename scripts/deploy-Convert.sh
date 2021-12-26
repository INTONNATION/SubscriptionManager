#!/bin/bash
set -xe

LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD
tos=tonos-cli

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi

name=`echo m$1 | xxd -ps -c 20000`
cp ../contracts/mTIP-3/mRootTokenContract.sol ../contracts/mTIP-3/m$1RootTokenContract.sol
cp ../contracts/mTIP-3/mTONTokenWallet.sol ../contracts/mTIP-3/m$1TokenWallet.sol
tondev sol compile ../contracts/mTIP-3/m$1RootTokenContract.sol -o ../abi;
tondev sol compile ../contracts/mTIP-3/m$1TokenWallet.sol -o ../abi;
rm ../contracts/mTIP-3/m$1RootTokenContract.sol
rm ../contracts/mTIP-3/m$1TokenWallet.sol

tondev sol compile ../contracts/ConvertTIP3.sol -o ../abi;

# $1 wallet code
wallet_code=`tvm_linker decode --tvc ../abi/$1TokenWallet.tvc | grep 'code:' | awk '{print $NF}'`
# m$1 wallet code
m_wallet_code=`tvm_linker decode --tvc ../abi/m$1TokenWallet.tvc | grep 'code:' | awk '{print $NF}'`
tvc=`tvm_linker init ../abi/m$1RootTokenContract.tvc "{\"_randomNonce\": 1, \"name\": \"$name\",\"symbol\": \"$name\", \"decimals\": 6, \"wallet_code\": \"$m_wallet_code\"}" ../abi/m$1RootTokenContract.abi.json | grep 'Saved contract to file' | awk '{print $NF}'`
mv $tvc ../abi/m$1RootTokenContract.tvc

# Converter contract code
tvc=`tvm_linker init ../abi/ConvertTIP3.tvc "{\"tip3_wallet_code\": \"$wallet_code\"}" ../abi/ConvertTIP3.abi.json | grep 'Saved contract to file' | awk '{print $NF}'`
mv $tvc ../abi/ConvertTIP3.tvc

# Giver FLD
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
function giver {
       $tos --url $NETWORK call --abi ../abi/local_giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":20000000000}"
}

# Giver DEVNET
#giver=0:ece57bcc6c530283becbbd8a3b24d3c5987cdddc3c8b7b33be6e4a6312490415
#function giver {
#$tos --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":5000000000, \"bounce\":\"false\"}"
#}

function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function get_wallet_address {
echo $(cat log.log | grep "value0" | cut -d ' ' -f 4| tr -d \")
}

function genseed {
$tos genphrase > $1.seed
}

function genseedConvert {
genseed ConvertTIP3
seed=`cat ConvertTIP3.seed | grep -o '".*"' | tr -d '"'`
echo " seed - $seed"
genkeypair "ConvertTIP3" "$seed"       
}

function genkeypair {
$tos getkeypair $1.keys.json "$2"
}

function genaddr {
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey $1.keys.json > log.log
}

function genaddrConvert {
$tos genaddr ../abi/ConvertTIP3.tvc ../abi/ConvertTIP3.abi.json --setkey ConvertTIP3.keys.json > log.log
}

function deployConvert_m {
pub=`cat ConvertTIP3.keys.json | jq .public -r`
echo GENADDR ConvertTIP3 ----------------------------------------------
genaddr ConvertTIP3
CONTRACT_ADDRESS=$(get_address)
echo GIVER ConvertTIP3 ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY ConvertTIP3 -----------------------------------------------
$tos --url $NETWORK deploy ../abi/ConvertTIP3.tvc '{"tip3_token_root_": "'$(cat $1RootTokenContract.addr)'", "mtip3_token_root_": "'$(cat m$1RootTokenContract.addr)'","tip3_token_wallet_": "'$(cat $1ConvertWallet.addr)'","mtip3_token_wallet_":"'$(cat m$1ConvertWallet.addr)'"}' --sign ConvertTIP3.keys.json --abi ../abi/ConvertTIP3.abi.json
echo -n $CONTRACT_ADDRESS > ConvertTIP3.addr
$tos --url $NETWORK call $CONTRACT_ADDRESS setReceiveCallback '{}' --abi ../abi/ConvertTIP3.abi.json --sign ConvertTIP3.keys.json
}

function deployRoot_m {
genseed m$1RootTokenContract
seed=`cat m$1RootTokenContract.seed | grep -o '".*"' | tr -d '"'`
echo "DeBot seed - $seed"
genkeypair "m$1RootTokenContract" "$seed"
pub=`cat m$1RootTokenContract.keys.json | jq .public -r`
echo GENADDR m$1RootTokenContract ----------------------------------------------
genaddr m$1RootTokenContract
CONTRACT_ADDRESS=$(get_address)
echo GIVER m$1RootTokenContract ------------------------------------------------
giver $CONTRACT_ADDRESS
echo DEPLOY m$1RootTokenContract -----------------------------------------------
$tos --url $NETWORK deploy ../abi/m$1RootTokenContract.tvc "{\"root_public_key_\": \"0x$pub\", \"root_owner_address_\": \"0:0000000000000000000000000000000000000000000000000000000000000000\"}" --sign m$1RootTokenContract.keys.json --abi ../abi/m$1RootTokenContract.abi.json
echo -n $CONTRACT_ADDRESS > m$1RootTokenContract.addr
IMAGE=$(base64 $prefix ../abi/Subscription.tvc)
$tos --url $NETWORK call $CONTRACT_ADDRESS setSubscriptionImage "{\"image\":\"$IMAGE\"}" --sign m$1RootTokenContract.keys.json --abi ../abi/m$1RootTokenContract.abi.json
giver $CONTRACT_ADDRESS
}

function deployWallet {
genaddrConvert
convert_address=`get_address`
$tos --url $NETWORK call `cat $1RootTokenContract.addr` deployWallet '{"tokens": 11, "deploy_grams": 1000000000, "wallet_public_key_": "0x0000000000000000000000000000000000000000000000000000000000000000", "owner_address_": "'$convert_address'","gas_back_address": "'$(cat $1RootTokenContract.addr)'"}' --abi ../abi/$1RootTokenContract.abi.json --sign $1RootTokenContract.keys.json > log.log
wallet_address=`get_wallet_address`
echo $wallet_address > $1ConvertWallet.addr
}

function deployWallet_m {
pub=`cat m$1RootTokenContract.keys.json | jq .public -r`
genaddrConvert
convert_address=`get_address`
$tos --url $NETWORK call `cat m$1RootTokenContract.addr` deployWallet '{"tokens": 1000, "deploy_grams": 1000000000, "wallet_public_key_": "0x0000000000000000000000000000000000000000000000000000000000000000", "owner_address_": "'$convert_address'","gas_back_address": "'$(cat m$1RootTokenContract.addr)'"}' --abi ../abi/m$1RootTokenContract.abi.json --sign m$1RootTokenContract.keys.json > log.log
wallet_address=`get_wallet_address`
echo $wallet_address > m$1ConvertWallet.addr
genaddrConvert
convert_address=`get_address`
$tos --url $NETWORK call `cat m$1RootTokenContract.addr` transferOwner '{"root_public_key_":"0x0000000000000000000000000000000000000000000000000000000000000000","root_owner_address_":"'$convert_address'"}' --abi ../abi/m$1RootTokenContract.abi.json --sign m$1RootTokenContract.keys.json > log.log
}

genseedConvert
deployRoot_m
deployWallet_m
deployWallet
deployConvert_m