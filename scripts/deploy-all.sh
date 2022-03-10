#!/bin/bash
set -xe

# Need to run once to deploy TIP-3 tokens (emulation of main net)
#./deploy-TIP-3.sh MTDS (decimals?)
#./deploy-TIP-3.sh USDT
#./deploy-TIP-3.sh EUPI

# configs
./deploy-configVersions.sh

./deploy-MetaduesRoot.sh







