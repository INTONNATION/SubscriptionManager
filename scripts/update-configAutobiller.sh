#!/bin/bash

set -xe

if [[ `uname` = "Linux" ]]; then
    prefix="-w0"
fi


# Params
pubkey=$(echo '0x9b5bcf6ccdb180da143fa9fa784abb8917efabda1dde9fddede28e392e4c1b43'| base64 $prefix)
name=$(echo 'Autobiller'| base64 $prefix)
period=$(echo '3000000'| base64 $prefix)
value=$(echo '1'| base64 $prefix)
image=$(echo 'QmenYzWrNpCbK6LhHHXxhusT6qNEnYQrkpDz6DBVqX6Tu3'| base64 $prefix)
description=$(echo 'Autobiller'| base64 $prefix)
to=$(echo '0:af1eec292203b858a374c06992e37d6a3df90b34e2c5362dc5f332cf41b4d53e'| base64 $prefix)
category=$(echo 'Other'| base64 $prefix)


LOCALNET=http://127.0.0.1
DEVNET=https://net.ton.dev
MAINNET=https://main.ton.dev
FLD=https://gql.custler.net
NETWORK=$FLD

configAddr=$(cat ./configAutobiller.addr)
echo $configAddr

tonos-cli --url $NETWORK call $configAddr setAutobillerConfig "{\"pubkeyINPUT\": \"$pubkey\", \"nameINPUT\": \"$name\",\"periodINPUT\": \"$period\",\"valueINPUT\": \"$value\",\"imageINPUT\": \"$image\",\"descriptionINPUT\": \"$description\",\"toINPUT\": \"$to\",\"categoryINPUT\": \"$category\"}" --abi ../abi/configAutobiller.abi.json --sign configAutobiller.keys.json