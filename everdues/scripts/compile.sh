#!/bin/bash
set -xe

tondev sol compile ../contracts/root/EverduesRoot.sol -o ../abi;
tondev sol compile ../contracts/account/EverduesAccountV1.sol -o ../abi;
tondev sol compile ../contracts/Platform.sol -o ../abi;
tondev sol compile ../contracts/subscription/EverduesSubscriptionV1.sol -o ../abi;
tondev sol compile ../contracts/Index.sol -o ../abi;
tondev sol compile ../contracts/service/EverduesServiceV1.sol -o ../abi;
tondev sol compile ../contracts/feeProxy/EverduesFeeProxy.sol -o ../abi;
