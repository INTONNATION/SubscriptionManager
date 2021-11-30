
#!/bin/bash
set -xe

#for i in ../debots/SubsMan ../debots/clientDebot ../contracts/Subscription ../debots/serviceDebot ../contracts/SubscriptionServiceIndex ../contracts/SubscriptionService ../contracts/SubscriptionIndex ../contracts/Wallet; do
#	tondev sol compile $i.sol -o ../abi;
#done
for i in ../debots/SubsMan ../contracts/Subscription ../contracts/SubscriptionServiceIndex ../contracts/SubscriptionService ../contracts/SubscriptionIndex ../contracts/Wallet; do
       tondev sol compile $i.sol -o ../abi;
done

tos=tonos-cli

## SETUP CONFIG
##TONOSCLI_CONFIG=./tonos-cli.config.json
##$tos config --url https://gql.custler.net --wc 0 --lifetime 3600 --retries 3 --timeout 600 --async_call true

DEBOT_NAME=SubsMan
DEBOT_CLIENT=clientDebot
# FLD old giver
#giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94

giver=0:ece57bcc6c530283becbbd8a3b24d3c5987cdddc3c8b7b33be6e4a6312490415

# FLD old giver
# function giver {
# $tos --url $NETWORK call --abi ../abi/local_giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":20000000000}"
# }

function giver {
       $tos --url $NETWORK call --sign ../abi/GiverV2.keys.json --abi ../abi/GiverV2.abi.json $giver sendTransaction "{\"dest\":\"$1\",\"value\":5000000000, \"bounce\":\"false\"}"
}

function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function genseed {
$tos genphrase > $1.seed
}

function genpubkey {
$tos genpubkey "$1" > $2.pub
}

function genkeypair {
$tos getkeypair $1.keys.json "$2"
}

function genaddrclient {
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey client.keys.json > log.log
}

function genaddrservice {
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey service.keys.json > log.log
}
function genaddr {
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --setkey $1.keys.json > log.log
}
function genaddrgen {
$tos genaddr ../abi/$1.tvc ../abi/$1.abi.json --genkey $1.keys.json > log.log
}

function deploy {
genseed $1
seed=`cat $1.seed | grep -o '".*"' | tr -d '"'`
echo "DeBot seed - $seed"
genpubkey "$seed" "client"
pub=`cat $1.pub | grep "Public key" | awk '{print $3}'`
echo "Debot pubkey - $pub"
genkeypair "$1" "$seed"
echo GENADDR $1 ----------------------------------------------
genaddr $1
DEBOT_ADDRESS=$(get_address)
echo GIVER $1 ------------------------------------------------
giver $DEBOT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
$tos --url $NETWORK deploy ../abi/$1.tvc "{}" --sign $1.keys.json --abi ../abi/$1.abi.json
DEBOT_ABI=$(cat ../abi/$1.abi.json | jq -c . | xxd -ps -c 20000)
$tos --url $NETWORK call $DEBOT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" --sign $1.keys.json --abi ../abi/$1.abi.json
echo -n $DEBOT_ADDRESS > $1.addr
}
function deploygen {
echo GENADDR $1 ----------------------------------------------
genaddrgen $1
DEBOT_ADDRESS=$(get_address)
echo GIVER $1 ------------------------------------------------
giver $DEBOT_ADDRESS
echo DEPLOY $1 -----------------------------------------------
$tos --url $NETWORK deploy ../abi/$1.tvc "{}" --sign $1.keys.json --abi ../abi/$1.abi.json
DEBOT_ABI=$(cat ../abi/$1.abi.json | jq -c . | xxd -ps -c 20000)
$tos --url $NETWORK call $DEBOT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" --sign $1.keys.json --abi ../abi/$1.abi.json
echo -n $DEBOT_ADDRESS > $1.addr
}

function deployMsigClient {
genseed client
seed=`cat client.seed | grep -o '".*"' | tr -d '"'`
echo "Client seed - $seed"
genpubkey "$seed" "client"
pub=`cat client.pub | grep "Public key" | awk '{print $3}'`
echo "Client pubkey - $pub"
genkeypair "client" "$seed"
msig=SafeMultisigWallet
echo GENADDR $msig ----------------------------------------------
genaddrclient $msig
ADDRESS=$(get_address)
echo GIVER $msig ------------------------------------------------
giver $ADDRESS
echo DEPLOY $msig -----------------------------------------------
PUBLIC_KEY=$(cat client.keys.json | jq .public)
$tos --url $NETWORK deploy ../abi/$msig.tvc "{\"owners\":[\"0x${PUBLIC_KEY:1:64}\"],\"reqConfirms\":1}" --sign client.keys.json --abi ../abi/$msig.abi.json
echo -n $ADDRESS > msig.client.addr
}

function deployMsigService {
genseed service
seed=`cat service.seed | grep -o '".*"' | tr -d '"'`
echo "Service seed - $seed"
genpubkey "$seed" "service"
pub=`cat service.pub | grep "Public key" | awk '{print $3}'`
echo "Service pubkey - $pub"
genkeypair "service" "$seed"
msig=SafeMultisigWallet
echo GENADDR $msig ----------------------------------------------
genaddrservice $msig
ADDRESS=$(get_address)
echo GIVER $msig ------------------------------------------------
giver $ADDRESS
echo DEPLOY $msig -----------------------------------------------
PUBLIC_KEY=$(cat service.keys.json | jq .public)
$tos --url $NETWORK deploy ../abi/$msig.tvc "{\"owners\":[\"0x${PUBLIC_KEY:1:64}\"],\"reqConfirms\":1}" --sign service.keys.json --abi ../abi/$msig.abi.json
echo -n $ADDRESS > msig.service.addr
}


LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$DEVNET

deployMsigClient
deployMsigService
MSIG_CLIENT_ADDRESS=$(cat msig.client.addr)
MSIG_SERVICE_ADDRESS=$(cat msig.service.addr)
#
deploy $DEBOT_NAME
DEBOT_ADDRESS=$(cat $DEBOT_NAME.addr)
ACCMAN_ADDRESS=$DEBOT_ADDRESS

IMAGE=$(base64 -w 0 ../abi/Subscription.tvc)
$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionBase "{\"image\":\"$IMAGE\"}" --sign $DEBOT_NAME.keys.json --abi ../abi/$DEBOT_NAME.abi.json
IMAGE=$(base64 -w 0 ../abi/Wallet.tvc)
$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionWalletCode "{\"image\":\"$IMAGE\"}" --sign $DEBOT_NAME.keys.json --abi ../abi/$DEBOT_NAME.abi.json

IMAGE=$(base64 -w 0 ../abi/SubscriptionIndex.tvc)
$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionIndexCode "{\"image\":\"$IMAGE\"}" --sign $DEBOT_NAME.keys.json --abi ../abi/$DEBOT_NAME.abi.json
# SET IMAGE for SERVICE
IMAGE=$(base64 -w 0 ../abi/SubscriptionService.tvc)
$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionService "{\"image\":\"$IMAGE\"}" --sign $DEBOT_NAME.keys.json --abi ../abi/$DEBOT_NAME.abi.json
# SET IMAGE for SERVICE INDEX
IMAGE=$(base64 -w 0 ../abi/SubscriptionServiceIndex.tvc)
$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionServiceIndex "{\"image\":\"$IMAGE\"}" --sign $DEBOT_NAME.keys.json --abi ../abi/$DEBOT_NAME.abi.json
echo DONE ------------------------------------------------------------------
echo debot $DEBOT_ADDRESS

##ACCMAN_ADDRESS=0:e20b930f512c6bee12e3f62f868eb428ec10e7159d4394d6377cc8a306ddf49f
#deploy $DEBOT_CLIENT
#DEBOT_ADDRESS=$(cat $DEBOT_CLIENT.addr)
#$tos --url $NETWORK call $DEBOT_ADDRESS setSubsman "{\"addr\":\"$ACCMAN_ADDRESS\"}" --sign $DEBOT_CLIENT.keys.json --abi ../abi/$DEBOT_CLIENT.abi.json
### SET WALLET IMAGE
#IMAGE=$(base64 -w 0 ../abi/Wallet.tvc)
#$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionWalletCode "{\"image\":\"$IMAGE\"}" --sign $DEBOT_NAME.keys.json --abi ../abi/$DEBOT_NAME.abi.json
### SET IMAGE for SERVICE
#IMAGE=$(base64 -w 0 ../abi/SubscriptionService.tvc)
#$tos --url $NETWORK call $DEBOT_ADDRESS setSubscriptionService "{\"image\":\"$IMAGE\"}" --sign $DEBOT_CLIENT.keys.json --abi ../abi/$DEBOT_CLIENT.abi.json
#
## SERVICE DEBOT DEPLOY
#deploygen serviceDebot
#DEBOT_ADDRESS_SVC=$(cat serviceDebot.addr)
#$tos --url $NETWORK call $DEBOT_ADDRESS_SVC setSubsman "{\"addr\":\"$ACCMAN_ADDRESS\"}" --sign serviceDebot.keys.json --abi ../abi/serviceDebot.abi.json
#$tos --url $NETWORK call $DEBOT_ADDRESS_SVC setSubscriptionService "{\"image\":\"$IMAGE\"}" --sign serviceDebot.keys.json --abi ../abi/serviceDebot.abi.json

#echo client $DEBOT_ADDRESS
#echo service $DEBOT_ADDRESS_SVC
#echo debot $ACCMAN_ADDRESS
#echo msig_client $MSIG_CLIENT_ADDRESS
#echo msig_service $MSIG_SERVICE_ADDRESS

cat msig.client.addr
cat msig.service.addr
cat client.keys.json
cat service.keys.json
#
#tonos-cli config --pubkey 0x$(cat client.keys.json | jq .public -r) --wallet $(cat msig.client.addr)
#$tos --url $NETWORK debot fetch `cat clientDebot.addr`
#tonos-cli config --pubkey 0x$(cat service.keys.json | jq .public -r) --wallet $(cat msig.service.addr)
#$tos --url $NETWORK debot fetch `cat serviceDebot.addr`
