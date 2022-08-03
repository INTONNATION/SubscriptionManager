#!/bin/bash
set -xe

everdev sol compile ../contracts/root/EverduesRoot.sol -o ../abi;
everdev sol compile ../contracts/account/EverduesAccountV1.sol -o ../abi;
everdev sol compile ../contracts/Platform.sol -o ../abi;
everdev sol compile ../contracts/subscription/EverduesSubscriptionV1.sol -o ../abi;
everdev sol compile ../contracts/Index.sol -o ../abi;
everdev sol compile ../contracts/service/EverduesServiceV1.sol -o ../abi;
everdev sol compile ../contracts/feeProxy/EverduesFeeProxy.sol -o ../abi;
