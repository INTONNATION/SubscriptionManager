#!/bin/bash
set -xe

tondev sol compile ../contracts/EverduesRoot.sol -o ../abi;
tondev sol compile ../contracts/EverduesAccount.sol -o ../abi;
tondev sol compile ../contracts/Platform.sol -o ../abi;
tondev sol compile ../contracts/Subscription.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIndex.sol -o ../abi;
tondev sol compile ../contracts/SubscriptionIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/Service.sol -o ../abi;
tondev sol compile ../contracts/ServiceIndex.sol -o ../abi;
tondev sol compile ../contracts/ServiceIdentificatorIndex.sol -o ../abi;
tondev sol compile ../contracts/EverduesFeeProxy.sol -o ../abi;
